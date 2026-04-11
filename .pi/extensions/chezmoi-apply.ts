import {
  type ExtensionAPI,
  isEditToolResult,
  isWriteToolResult,
} from "@mariozechner/pi-coding-agent";
import { isAbsolute, relative, resolve } from "node:path";

function isSubpath(parent: string, child: string): boolean {
  const rel = relative(parent, child);
  return rel !== "" && !rel.startsWith("..") && !isAbsolute(rel);
}

export default function (pi: ExtensionAPI) {
  let sourceDir: string | null = null;
  let applyQueue: Promise<void> = Promise.resolve();

  pi.on("session_start", async (_event, ctx) => {
    const { code, stdout } = await pi.exec("chezmoi", ["source-path"], {
      cwd: ctx.cwd,
    });
    sourceDir = code === 0 ? stdout.trim() || null : null;
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!sourceDir) return;
    if (!(isEditToolResult(event) || isWriteToolResult(event)) || event.isError)
      return;
    if (typeof event.input.path !== "string") return;

    const sourcePath = resolve(ctx.cwd, event.input.path);
    if (!isSubpath(sourceDir, sourcePath)) return;

    const run = async () => {
      const targetResult = await pi.exec(
        "chezmoi",
        ["target-path", sourcePath],
        {
          cwd: ctx.cwd,
          signal: ctx.signal,
        },
      );

      if (targetResult.killed || targetResult.code !== 0) {
        // Ignore files not managed by chezmoi and aborted runs.
        return;
      }

      const targetPath = targetResult.stdout.trim();
      if (!targetPath) return;

      const applyResult = await pi.exec(
        "chezmoi",
        ["apply", "--no-tty", targetPath],
        {
          cwd: ctx.cwd,
          signal: ctx.signal,
        },
      );

      if (applyResult.killed || applyResult.code === 0) {
        return;
      }

      if (ctx.hasUI) {
        const message =
          applyResult.stderr.trim() ||
          `chezmoi exited with code ${applyResult.code}`;
        ctx.ui.notify(
          `chezmoi apply failed for ${targetPath}: ${message}`,
          "warning",
        );
      }
    };

    const next = applyQueue.then(run, run);
    applyQueue = next.catch(() => {});
    await next;
  });
}
