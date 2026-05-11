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
  let reAddQueue: Promise<void> = Promise.resolve();

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

    const targetPath = resolve(ctx.cwd, event.input.path);
    // Skip edits to source directory files
    if (isSubpath(sourceDir, targetPath)) return;

    const run = async () => {
      // Check if this target file is managed by chezmoi
      const sourcePathResult = await pi.exec("chezmoi", ["source-path", targetPath], {
        cwd: ctx.cwd,
        signal: ctx.signal,
      });

      if (sourcePathResult.killed || sourcePathResult.code !== 0) {
        // Not managed by chezmoi or aborted — ignore silently
        return;
      }

      const sourcePath = sourcePathResult.stdout.trim();
      if (!sourcePath) return;

      // Re-add the target file to sync changes back to source state
      const reAddResult = await pi.exec("chezmoi", ["re-add", "--no-tty", targetPath], {
        cwd: ctx.cwd,
        signal: ctx.signal,
      });

      if (reAddResult.killed || reAddResult.code === 0) return;

      if (ctx.hasUI) {
        const message = reAddResult.stderr.trim() || `chezmoi exited with code ${reAddResult.code}`;
        ctx.ui.notify(`chezmoi re-add failed for ${targetPath}: ${message}`, "warning");
      }
    };

    const next = reAddQueue.then(run, run);
    reAddQueue = next.catch(() => {});
    await next;
  });
}
