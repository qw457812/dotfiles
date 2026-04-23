// Copied from: https://github.com/telagod/oh-pi/blob/33c427394b8459f963fe56f7f3150d3fddef41f6/pi-package/extensions/safe-guard.ts

/**
 * oh-pi Safe Guard Extension
 *
 * Combines destructive command confirmation + protected paths in one extension.
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";

export const DANGEROUS_PATTERNS = [
  /\brm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|.*-rf\b|.*--force\b)/,
  /\bsudo\s+rm\b/,
  /\b(DROP|TRUNCATE|DELETE\s+FROM)\b/i,
  /\bchmod\s+777\b/,
  /\bmkfs\b/,
  /\bdd\s+if=/,
  />\s*\/dev\/sd[a-z]/,
];

export const PROTECTED_PATHS = [".env", ".git/", "node_modules/", ".pi/", "id_rsa", ".ssh/"];

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
  pi.on("tool_call", async (event, ctx) => {
    // Check bash commands for dangerous patterns
    if (event.toolName === "bash") {
      const cmd = (event.input as { command?: string }).command ?? "";
      const match = DANGEROUS_PATTERNS.find((p) => p.test(cmd));
      if (match && ctx.hasUI) {
        notify("Pi Danger Approval Needed", cmd);
        const ok = await ctx.ui.confirm("⚠️ Dangerous Command", `Execute: ${cmd}?`);
        if (!ok) {
          ctx.abort();
          return { block: true, reason: "Blocked by user" };
        }
      }
    }

    // Check write/edit for protected paths
    if (event.toolName === "write" || event.toolName === "edit") {
      const path = (event.input as { path?: string }).path ?? "";
      const hit = PROTECTED_PATHS.find((p) => path.includes(p));
      if (hit) {
        if (ctx.hasUI) {
          notify("Pi Path Approval Needed", path);
          const ok = await ctx.ui.confirm("🛡️ Protected Path", `Allow write to ${path}?`);
          if (!ok) {
            ctx.abort();
            return { block: true, reason: `Protected path: ${hit}` };
          }
        } else {
          return { block: true, reason: `Protected path: ${hit}` };
        }
      }
    }
  });
}
