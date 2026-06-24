/**
 * Prompt Viewer — inspect the current system prompt and last provider payload.
 *
 * Commands:
 *   /prompt   Open the effective system prompt (ctx.getSystemPrompt()) in $VISUAL/$EDITOR.
 *   /payload  Open the last provider request payload, captured from
 *             `before_provider_request`. Send any message first so there is
 *             something to show.
 *
 * Outside TUI, or when no editor is set, the text is written to a temp file
 * and its path is reported via notify, so it can be opened with a pager.
 *
 * Ref: docs/extensions.md (registerCommand, ctx.getSystemPrompt,
 * before_provider_request), extensions/hide-skills.ts (openDiffInEditor flow),
 * examples/extensions/provider-payload.ts (payload capture).
 */
import { type ExtensionAPI, type ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

/** Most recently serialized provider request payload, captured per turn. */
let lastPayload: unknown = undefined;

export default function (pi: ExtensionAPI) {
  pi.on("before_provider_request", (event) => {
    lastPayload = event.payload;
  });

  pi.registerCommand("prompt", {
    description: "Open the current system prompt in $EDITOR",
    handler: async (_args, ctx) => {
      await openInEditor(ctx, ctx.getSystemPrompt(), "md");
    },
  });

  pi.registerCommand("payload", {
    description: "Open the last provider request payload in $EDITOR",
    handler: async (_args, ctx) => {
      if (lastPayload === undefined) {
        ctx.ui.notify("No provider request yet — send a message first", "warning");
        return;
      }
      await openInEditor(ctx, JSON.stringify(lastPayload, null, 2), "json");
    },
  });
}

async function openInEditor(
  ctx: ExtensionCommandContext,
  text: string,
  ext: string,
): Promise<void> {
  const editorCmd = process.env.VISUAL || process.env.EDITOR;
  if (ctx.mode !== "tui" || !editorCmd) {
    const fallbackPath = join(tmpdir(), `pi-extension-editor-prompt-viewer-${Date.now()}.${ext}`);
    writeFileSync(fallbackPath, text);
    ctx.ui.notify(`Written to ${fallbackPath}`, "info");
    return;
  }

  await ctx.ui.custom<void>((tui, _theme, _kb, done) => {
    const filePath = join(tmpdir(), `pi-extension-editor-prompt-viewer-${Date.now()}.${ext}`);
    let stopped = false;

    void (async () => {
      try {
        writeFileSync(filePath, text);
        tui.stop();
        stopped = true;

        const [editor, ...editorArgs] = editorCmd.split(" ");
        process.stdout.write(
          `Opening ${filePath} in ${editorCmd}\nPi will resume when the editor exits.\n`,
        );
        await new Promise<void>((resolve) => {
          const child = spawn(editor, [...editorArgs, filePath], {
            stdio: "inherit",
            shell: process.platform === "win32",
            env: process.env,
          });
          child.on("error", () => resolve());
          child.on("close", () => resolve());
        });
      } finally {
        rmSync(filePath, { force: true });
        if (stopped) {
          tui.start();
          tui.requestRender(true);
        }
        done();
      }
    })();

    return { render: () => [], invalidate: () => {} };
  });
}
