// Ref: https://github.com/telagod/oh-pi/blob/7e59d1bcbfe1af837494a65d759d047a6474b103/pi-package/extensions/git-guard.ts

/**
 * Git Guard Extension
 *
 * Combines mutating git command confirmation + dirty-repo-guard.
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// const GUARDED_GIT_PATTERN = /\bgit(?:\s+-C\s+(?:"[^"]*"|'[^']*'|\S+))*\s+(?<subcommand>add|commit|push|pull|merge|rebase|reset|checkout|switch|stash|cherry-pick|revert|restore|clean)\b/;

export default function (pi: ExtensionAPI) {
  // Using the `permissionGate` feature from `npm:@aliou/pi-guardrails` instead
  // pi.on("tool_call", async (event, ctx) => {
  //   if (event.toolName !== "bash") return;
  //
  //   const command = (event.input as { command?: string }).command ?? "";
  //   const subcommand = command.match(GUARDED_GIT_PATTERN)?.groups?.subcommand;
  //   if (!subcommand) return;
  //
  //   if (!ctx.hasUI) {
  //     return { block: true, reason: `Git ${subcommand} requires user confirmation` };
  //   }
  //
  //   pi.events.emit("my:notification", { title: "Pi Git Approval Needed", body: command });
  //   const ok = await ctx.ui.confirm(`🔐 Allow git ${subcommand}?`, command);
  //   if (!ok) {
  //     ctx.abort();
  //     return { block: true, reason: "Blocked by user" };
  //   }
  // });

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
}
