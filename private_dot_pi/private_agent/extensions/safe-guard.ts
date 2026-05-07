// Copied from: https://github.com/telagod/oh-pi/blob/33c427394b8459f963fe56f7f3150d3fddef41f6/pi-package/extensions/safe-guard.ts

/**
 * oh-pi Safe Guard Extension
 *
 * Combines destructive command confirmation + protected paths in one extension.
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// export const DANGEROUS_PATTERNS = [
//   /\brm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|.*-rf\b|.*--force\b)/,
//   /\bsudo\s+rm\b/,
//   /\b(DROP|TRUNCATE|DELETE\s+FROM)\b/i,
//   /\bchmod\s+777\b/,
//   /\bmkfs\b/,
//   /\bdd\s+if=/,
//   />\s*\/dev\/sd[a-z]/,
// ];

export const PROTECTED_PATHS = [".env", ".git/", "node_modules/", ".pi/", "id_rsa", ".ssh/"];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    // Using the `permissionGate` feature from `npm:@aliou/pi-guardrails` instead
    // // Check bash commands for dangerous patterns
    // if (event.toolName === "bash") {
    //   const cmd = (event.input as { command?: string }).command ?? "";
    //   const match = DANGEROUS_PATTERNS.find((p) => p.test(cmd));
    //   if (match && ctx.hasUI) {
    //     pi.events.emit("my:notification", { title: "Pi Danger Approval", body: cmd });
    //     const ok = await ctx.ui.confirm("⚠️ Dangerous Command", `Execute: ${cmd}?`);
    //     if (!ok) {
    //       ctx.abort();
    //       return { block: true, reason: "Blocked by user" };
    //     }
    //   }
    // }

    // Check write/edit for protected paths
    if (event.toolName === "write" || event.toolName === "edit") {
      const path = (event.input as { path?: string }).path ?? "";
      const hit = PROTECTED_PATHS.find((p) => path.includes(p));
      if (hit) {
        if (ctx.hasUI) {
          pi.events.emit("my:notification", { title: "Pi Path Approval", body: path });
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
