// Ref: https://github.com/telagod/oh-pi/blob/7e59d1bcbfe1af837494a65d759d047a6474b103/pi-package/extensions/git-guard.ts

/**
 * oh-pi Git Checkpoint Extension
 *
 * Auto-stash before each turn.
 * Combines git-checkpoint + dirty-repo-guard.
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";

const GUARDED_GIT_PATTERN = /\bgit\s+(?<subcommand>add|commit|push|pull|merge|rebase|reset|checkout|switch|stash|cherry-pick|revert|restore)\b/;

const notify = (title: string, body: string): void => {
  if (process.platform === "darwin") {
    const script = `on run argv
display notification (item 2 of argv) with title (item 1 of argv)
end run`;
    const proc = spawn("osascript", ["-e", script, "--", title, body], { stdio: "ignore" });
    proc.once("error", () => {});
    proc.unref();
  } else if (process.env.TERMUX_VERSION) {
    const proc = spawn("termux-notification", ["-t", title, "-c", body], { stdio: "ignore" });
    proc.once("error", () => {});
    proc.unref();
  } else if (process.env.KITTY_WINDOW_ID) {
    process.stdout.write(`\x1b]99;i=1:d=0;${title}\x1b\\`);
    process.stdout.write(`\x1b]99;i=1:p=body;${body}\x1b\\`);
  } else {
    process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
  }
};

export default function (pi: ExtensionAPI) {
  let turnCount = 0;

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;

    const command = (event.input as { command?: string }).command ?? "";
    const subcommand = command.match(GUARDED_GIT_PATTERN)?.groups?.subcommand;
    if (!subcommand) return;

    if (!ctx.hasUI) {
      return { block: true, reason: `Git ${subcommand} requires user confirmation` };
    }

    notify("Pi Git Approval Needed", command);
    const ok = await ctx.ui.confirm(`🔐 Allow git ${subcommand}?`, command);
    if (!ok) {
      const reason = (await ctx.ui.input("Why block this Git command?", "optional reason"))?.trim();
      return {
        block: true,
        reason: reason
          ? `Git ${subcommand} blocked by user: ${reason}`
          : `Git ${subcommand} blocked by user`,
      };
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
