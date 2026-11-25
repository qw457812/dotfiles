// Adapted from: https://github.com/telagod/oh-pi/blob/33c427394b8459f963fe56f7f3150d3fddef41f6/pi-package/extensions/safe-guard.ts
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { confirm, confirmationResult } from "./confirmation.ts";

const PROTECTED_DIRECTORIES = new Set([".git", "node_modules", ".ssh"]);

export default function registerPathChecks(
  pi: ExtensionAPI,
  isEnabled: () => boolean = () => true,
) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isEnabled()) return;
    if (event.toolName !== "write" && event.toolName !== "edit") return;
    const path = (event.input as { path?: string }).path;
    if (!path) return;
    const protectedPath = resolve(ctx.cwd, path)
      .split("/")
      .some(
        (part) =>
          PROTECTED_DIRECTORIES.has(part) ||
          (part !== ".env.example" && (part === ".env" || part.startsWith(".env."))),
      );
    if (!protectedPath) return;

    const outcome = await confirm(pi, ctx, "🛡️ Protected Path", `Allow write to ${path}?`);
    return confirmationResult(outcome);
  });
}
