// Ref: https://github.com/telagod/oh-pi/blob/7e59d1bcbfe1af837494a65d759d047a6474b103/pi-package/extensions/git-guard.ts

/**
 * oh-pi Git Checkpoint Extension
 *
 * Auto-stash before each turn.
 * Combines git-checkpoint + dirty-repo-guard.
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const GUARDED_GIT_SUBCOMMANDS = [
  "add",
  "commit",
  "push",
  "pull",
  "merge",
  "rebase",
  "reset",
  "checkout",
  "switch",
  "stash",
  "cherry-pick",
  "revert",
  "restore",
];

function getGuardedGitCommand(command: string): string | null {
  const trimmed = command.trim();
  if (!trimmed.startsWith("git ")) return null;

  const match = trimmed.match(/^git\s+([\w-]+)/);
  if (!match) return null;

  const subcommand = match[1];
  return GUARDED_GIT_SUBCOMMANDS.includes(subcommand) ? subcommand : null;
}

export default function (pi: ExtensionAPI) {
  let turnCount = 0;

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;

    const command = (event.input as { command?: string }).command ?? "";
    const subcommand = getGuardedGitCommand(command);
    if (!subcommand) return;

    if (!ctx.hasUI) {
      return { block: true, reason: `Git ${subcommand} requires user confirmation` };
    }

    const ok = await ctx.ui.confirm("🔐 Confirm Git Command", `Run: ${command}?`);
    if (!ok) {
      return { block: true, reason: `Git ${subcommand} cancelled by user` };
    }
  });

  // Warn on dirty repo at session start
  pi.on("session_start", async (_event, ctx) => {
    try {
      const { stdout } = await pi.exec("git", ["status", "--porcelain"]);
      if (stdout.trim() && ctx.hasUI) {
        const lines = stdout.trim().split("\n").length;
        ctx.ui.notify(`⚠️ Dirty repo: ${lines} uncommitted change(s)`, "warning");
      }
    } catch { /* not a git repo, ignore */ }
  });

  // Stash checkpoint before each turn
  pi.on("turn_start", async () => {
    turnCount++;
    try {
      await pi.exec("git", ["stash", "create", "-m", `oh-pi-turn-${turnCount}`]);
    } catch { /* not a git repo */ }
  });

  pi.on("agent_end", async () => {
    turnCount = 0;
  });
}
