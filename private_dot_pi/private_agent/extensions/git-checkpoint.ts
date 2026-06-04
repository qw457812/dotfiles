/**
 * Git Checkpoint Extension
 *
 * Snapshots the working tree (including untracked files) at each turn_end
 * via `git write-tree`, keyed by the leaf session entryId (the just-finished
 * assistant message). On /fork, prompts the user to restore the working tree
 * and staged state to that snapshot.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Inspired by pi-rewind's temp-index snapshot + staged-state restore approach:
// https://github.com/arpagon/pi-rewind/blob/91611ad87992fb7b635a41ba68f67916ff6e6ae3/src/core.ts
interface Checkpoint {
  branch: string;
  indexTree: string;
  worktreeTree: string;
  preexistingUntrackedFiles: string[];
}

export default function (pi: ExtensionAPI) {
  const checkpoints = new Map<string, Checkpoint>();
  let gitDisabled = false;
  let gitChecked = false;

  function errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }

  async function execOrThrow(command: string, args: string[], action: string): Promise<string> {
    const result = await pi.exec(command, args);
    if (result.code !== 0) {
      const details =
        result.stderr.trim() || result.stdout.trim() || `${command} ${args.join(" ")}`;
      throw new Error(`${action} failed: ${details}`);
    }
    return result.stdout;
  }

  async function ensureGit(ctx: {
    hasUI: boolean;
    ui: { notify: (m: string, l: "info" | "warning" | "error") => void };
  }) {
    if (gitChecked) return;
    gitChecked = true;
    try {
      const result = await pi.exec("git", ["rev-parse", "--git-dir"]);
      if (result.code === 0) return;
    } catch {
      // Boundary-safe probe: failed git detection disables this extension.
    }

    gitDisabled = true;
    if (ctx.hasUI) ctx.ui.notify("git-checkpoint disabled: not a git repository", "warning");
  }

  async function currentBranch(): Promise<string> {
    const symbolic = await pi.exec("git", ["symbolic-ref", "--quiet", "--short", "HEAD"]);
    if (symbolic.code === 0) {
      const branch = symbolic.stdout.trim();
      if (!branch) throw new Error("read current branch failed: empty branch name");
      return branch;
    }

    // `git symbolic-ref --quiet` uses exit code 1 for detached HEAD.
    // Other non-zero codes are real command failures and should fail fast.
    if (symbolic.code !== 1) {
      const details =
        symbolic.stderr.trim() || symbolic.stdout.trim() || "git symbolic-ref --quiet --short HEAD";
      throw new Error(`read current branch failed: ${details}`);
    }

    const sha = (
      await execOrThrow("git", ["rev-parse", "--verify", "HEAD"], "read detached HEAD")
    ).trim();
    if (!sha) throw new Error("read detached HEAD failed: empty commit id");
    return `detached:${sha}`;
  }

  async function listUntrackedFiles(): Promise<string[]> {
    const stdout = await execOrThrow(
      "git",
      ["ls-files", "--others", "--exclude-standard", "-z"],
      "list untracked files",
    );
    return stdout.split("\0").filter(Boolean);
  }

  async function createSnapshot(): Promise<Checkpoint> {
    const [indexTreeOut, branch, preexistingUntrackedFiles] = await Promise.all([
      execOrThrow("git", ["write-tree"], "create index snapshot"),
      currentBranch(),
      listUntrackedFiles(),
    ]);

    // Use a temporary index so snapshotting never touches the user's staged state.
    // `pi.exec` does not support env overrides, so use a small shell wrapper for
    // GIT_INDEX_FILE + cleanup.
    const script = [
      "set -e",
      'idx="${TMPDIR:-/tmp}/pi-git-checkpoint-index.$$"',
      'rm -f "$idx"',
      "trap 'rm -f \"$idx\"' EXIT",
      "if git rev-parse --verify HEAD >/dev/null 2>&1; then",
      '  GIT_INDEX_FILE="$idx" git read-tree HEAD',
      "fi",
      'GIT_INDEX_FILE="$idx" git add -A',
      'GIT_INDEX_FILE="$idx" git write-tree',
    ].join("\n");
    const worktreeTreeOut = await execOrThrow("bash", ["-c", script], "create worktree snapshot");

    const indexTree = indexTreeOut.trim();
    const worktreeTree = worktreeTreeOut.trim();
    if (!indexTree) throw new Error("create index snapshot failed: empty tree id");
    if (!worktreeTree) throw new Error("create worktree snapshot failed: empty tree id");

    return { branch, indexTree, worktreeTree, preexistingUntrackedFiles };
  }

  function literalPathspec(path: string): string {
    return `:(literal)${path}`;
  }

  async function cleanNewUntrackedFiles(checkpoint: Checkpoint): Promise<void> {
    const preexisting = new Set(checkpoint.preexistingUntrackedFiles);
    const toRemove = (await listUntrackedFiles()).filter((path) => !preexisting.has(path));
    if (toRemove.length === 0) return;

    const batchSize = 100;
    for (let i = 0; i < toRemove.length; i += batchSize) {
      await execOrThrow(
        "git",
        ["clean", "-ff", "--", ...toRemove.slice(i, i + batchSize).map(literalPathspec)],
        "clean new untracked files",
      );
    }

    const remaining = new Set(await listUntrackedFiles());
    const failed = toRemove.filter((path) => remaining.has(path));
    if (failed.length > 0) {
      throw new Error(`clean new untracked files failed: still present: ${failed.join(", ")}`);
    }
  }

  pi.on("turn_end", async (_event, ctx) => {
    await ensureGit(ctx);
    if (gitDisabled) return;

    const leaf = ctx.sessionManager.getLeafEntry();
    if (!leaf) return;

    try {
      checkpoints.set(leaf.id, await createSnapshot());
    } catch (error) {
      // Event boundary: checkpoint failure is non-fatal, but should be visible.
      if (ctx.hasUI)
        ctx.ui.notify(`git-checkpoint snapshot failed: ${errorMessage(error)}`, "warning");
    }
  });

  pi.on("session_before_fork", async (event, ctx) => {
    if (!ctx.hasUI) return;

    const targetEntryId =
      event.position === "before"
        ? ctx.sessionManager.getEntry(event.entryId)?.parentId
        : event.entryId;
    if (!targetEntryId) return;

    const checkpoint = checkpoints.get(targetEntryId);
    if (!checkpoint) return;

    let branch: string;
    try {
      branch = await currentBranch();
    } catch (error) {
      ctx.ui.notify(`git-checkpoint restore unavailable: ${errorMessage(error)}`, "error");
      return;
    }

    if (branch !== checkpoint.branch) {
      ctx.ui.notify(
        `Checkpoint was created on ${checkpoint.branch}, but current branch is ${branch}; not restoring code state.`,
        "warning",
      );
      return;
    }

    const choice = await ctx.ui.select("Restore code state?", [
      "Yes, restore code to that point",
      "No, keep current code",
    ]);

    if (choice?.startsWith("Yes")) {
      try {
        // Fail fast: clean before changing the index, then only restore the
        // checkpoint index after the worktree restore succeeds.
        await cleanNewUntrackedFiles(checkpoint);
        await execOrThrow(
          "git",
          ["read-tree", "-u", "--reset", checkpoint.worktreeTree],
          "restore worktree",
        );
        await execOrThrow("git", ["read-tree", "--reset", checkpoint.indexTree], "restore index");
        ctx.ui.notify("Code restored to checkpoint", "info");
      } catch (error) {
        // Event boundary: translate restore failure into a visible error and
        // cancel the fork so conversation and code state do not diverge.
        ctx.ui.notify(`git-checkpoint restore failed: ${errorMessage(error)}`, "error");
        return { cancel: true };
      }
    }
  });
}
