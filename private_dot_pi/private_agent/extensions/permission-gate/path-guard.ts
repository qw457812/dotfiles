// Adapted from: https://github.com/telagod/oh-pi/blob/33c427394b8459f963fe56f7f3150d3fddef41f6/pi-package/extensions/safe-guard.ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { confirm, confirmationResult } from "./confirmation.ts";

const PROTECTED_PATHS = [".env", ".git/", "node_modules/", "id_rsa", ".ssh/"];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "write" && event.toolName !== "edit") return;
    const path = (event.input as { path?: string }).path ?? "";
    const hit = PROTECTED_PATHS.find((part) => path.includes(part));
    if (!hit) return;

    const outcome = await confirm(pi, ctx, "🛡️ Protected Path", `Allow write to ${path}?`);
    return confirmationResult(outcome);
  });
}
