/**
 * Auto-sync chezmoi source <-> target after pi edits:
 *   Source edited -> `chezmoi apply`  -> push to target
 *   Target edited -> `chezmoi re-add` -> pull to source
 *
 * Serialised queue; unmanaged files skipped; failures notified via UI.
 */

import {
  type ExtensionAPI,
  isEditToolResult,
  isWriteToolResult,
} from "@earendil-works/pi-coding-agent";
import { isAbsolute, relative, resolve } from "node:path";

function isSubpath(parent: string, child: string): boolean {
  const rel = relative(parent, child);
  return rel !== "" && !rel.startsWith("..") && !isAbsolute(rel);
}

export default function (pi: ExtensionAPI) {
  let sourceDir: string | null = null;
  let queue: Promise<void> = Promise.resolve();

  pi.on("session_start", async (_event, ctx) => {
    const { code, stdout } = await pi.exec("chezmoi", ["source-path"], {
      cwd: ctx.cwd,
    });
    sourceDir = code === 0 ? stdout.trim() || null : null;
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!sourceDir) return;
    if (!(isEditToolResult(event) || isWriteToolResult(event)) || event.isError) return;
    if (typeof event.input.path !== "string") return;

    const filePath = resolve(ctx.cwd, event.input.path);
    const inSourceDir = isSubpath(sourceDir, filePath);

    const run = async () => {
      if (inSourceDir) {
        // Source file edited -> apply to target
        const targetPathResult = await pi.exec("chezmoi", ["target-path", filePath], {
          cwd: ctx.cwd,
          signal: ctx.signal,
        });

        // File not managed by chezmoi (or run aborted)
        if (targetPathResult.killed || targetPathResult.code !== 0) return;

        const targetPath = targetPathResult.stdout.trim();
        if (!targetPath) return;

        const applyResult = await pi.exec("chezmoi", ["apply", "--no-tty", targetPath], {
          cwd: ctx.cwd,
          signal: ctx.signal,
        });

        if (applyResult.killed || applyResult.code === 0) return;

        if (ctx.hasUI) {
          const message =
            applyResult.stderr.trim() || `chezmoi exited with code ${applyResult.code}`;
          ctx.ui.notify(`chezmoi apply failed for ${targetPath}: ${message}`, "warning");
        }
      } else {
        // Target file edited -> re-add to source
        const sourcePathResult = await pi.exec("chezmoi", ["source-path", filePath], {
          cwd: ctx.cwd,
          signal: ctx.signal,
        });

        // File not managed by chezmoi (or run aborted)
        if (sourcePathResult.killed || sourcePathResult.code !== 0) return;

        const sourcePath = sourcePathResult.stdout.trim();
        if (!sourcePath) return;

        const reAddResult = await pi.exec("chezmoi", ["re-add", "--no-tty", filePath], {
          cwd: ctx.cwd,
          signal: ctx.signal,
        });

        if (reAddResult.killed || reAddResult.code === 0) return;

        if (ctx.hasUI) {
          const message =
            reAddResult.stderr.trim() || `chezmoi exited with code ${reAddResult.code}`;
          ctx.ui.notify(`chezmoi re-add failed for ${filePath}: ${message}`, "warning");
        }
      }
    };

    const next = queue.then(run, run);
    queue = next.catch(() => {});
    await next;
  });
}
