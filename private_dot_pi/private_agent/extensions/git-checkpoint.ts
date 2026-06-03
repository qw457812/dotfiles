/**
 * Git Checkpoint Extension
 *
 * Snapshots the working tree (including untracked files) at each turn_end
 * via `git write-tree`, keyed by the leaf session entryId (the just-finished
 * assistant message). On /fork, prompts the user to restore the working tree
 * and staged state to that snapshot.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

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
			// handled below
		}

		gitDisabled = true;
		if (ctx.hasUI)
			ctx.ui.notify("git-checkpoint disabled: not a git repository", "warning");
	}

	async function currentBranch(): Promise<string> {
		const { stdout, code } = await pi.exec("git", ["rev-parse", "--abbrev-ref", "HEAD"]);
		return code === 0 ? stdout.trim() || "unknown" : "unknown";
	}

	async function listUntrackedFiles(): Promise<string[]> {
		const { stdout, code } = await pi.exec("git", [
			"ls-files",
			"--others",
			"--exclude-standard",
			"-z",
		]);
		if (code !== 0 || !stdout) return [];
		return stdout.split("\0").filter(Boolean);
	}

	async function createSnapshot(): Promise<Checkpoint | undefined> {
		const [
			{ stdout: indexTreeOut, code: indexCode },
			branch,
			preexistingUntrackedFiles,
		] = await Promise.all([
			pi.exec("git", ["write-tree"]),
			currentBranch(),
			listUntrackedFiles(),
		]);
		if (indexCode !== 0) return undefined;

		// Use a temporary index so snapshotting never touches the user's staged state.
		// `pi.exec` does not support env overrides, so use a small shell wrapper for
		// GIT_INDEX_FILE + cleanup.
		const script = [
			"set -e",
			'idx="${TMPDIR:-/tmp}/pi-git-checkpoint-index.$$"',
			'rm -f "$idx"',
			'trap \'rm -f "$idx"\' EXIT',
			'if git rev-parse --verify HEAD >/dev/null 2>&1; then',
			'  GIT_INDEX_FILE="$idx" git read-tree HEAD',
			"fi",
			'GIT_INDEX_FILE="$idx" git add -A',
			'GIT_INDEX_FILE="$idx" git write-tree',
		].join("\n");
		const { stdout: worktreeTreeOut, code: worktreeCode } = await pi.exec("bash", [
			"-c",
			script,
		]);
		if (worktreeCode !== 0) return undefined;

		const indexTree = indexTreeOut.trim();
		const worktreeTree = worktreeTreeOut.trim();
		if (!indexTree || !worktreeTree) return undefined;

		return { branch, indexTree, worktreeTree, preexistingUntrackedFiles };
	}

	async function cleanNewUntrackedFiles(checkpoint: Checkpoint): Promise<void> {
		const preexisting = new Set(checkpoint.preexistingUntrackedFiles);
		const current = await listUntrackedFiles();
		const toRemove = current.filter((path) => !preexisting.has(path));
		if (toRemove.length === 0) return;

		const batchSize = 100;
		for (let i = 0; i < toRemove.length; i += batchSize) {
			const batch = toRemove.slice(i, i + batchSize);
			await pi.exec("git", ["clean", "-f", "--", ...batch]);
		}
	}

	pi.on("turn_end", async (_event, ctx) => {
		await ensureGit(ctx);
		if (gitDisabled) return;

		const leaf = ctx.sessionManager.getLeafEntry();
		if (!leaf) return;

		try {
			const checkpoint = await createSnapshot();
			if (checkpoint) checkpoints.set(leaf.id, checkpoint);
		} catch {
			// snapshot failure is non-fatal; skip this turn
		}
	});

	pi.on("session_before_fork", async (event, ctx) => {
		if (!ctx.hasUI) return;

		const checkpoint = checkpoints.get(event.entryId);
		if (!checkpoint) return;

		const branch = await currentBranch();
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
			// First restore files to the full worktree snapshot, clean untracked files
			// created after the checkpoint, then restore the staged state without
			// touching files. This preserves partial-staging boundaries.
			await pi.exec("git", ["read-tree", "-u", "--reset", checkpoint.worktreeTree]);
			await cleanNewUntrackedFiles(checkpoint);
			await pi.exec("git", ["read-tree", "--reset", checkpoint.indexTree]);
			ctx.ui.notify("Code restored to checkpoint", "info");
		}
	});
}
