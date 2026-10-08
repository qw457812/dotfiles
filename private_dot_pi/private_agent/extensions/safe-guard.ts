// Copied from: https://github.com/telagod/oh-pi/blob/33c427394b8459f963fe56f7f3150d3fddef41f6/pi-package/extensions/safe-guard.ts

/**
 * oh-pi Safe Guard Extension
 *
 * Protects write/edit paths.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";

const AGENT_DIR = getAgentDir();

const PROTECTED_PATHS = [
  ".env",
  ".git/",
  "node_modules/",
  // `${CONFIG_DIR_NAME}/`,
  "id_rsa",
  ".ssh/",
];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    // Check write/edit for protected paths
    if (event.toolName === "write" || event.toolName === "edit") {
      const path = (event.input as { path?: string }).path ?? "";
      const guardedPaths =
        ctx.cwd === AGENT_DIR
          ? PROTECTED_PATHS.filter((p) => p !== `${CONFIG_DIR_NAME}/`)
          : PROTECTED_PATHS;
      const hit = guardedPaths.find((p) => path.includes(p));
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
