/**
 * /last-message  Open the last assistant reply in $VISUAL/$EDITOR.
 *
 * The read-side counterpart of /copy (clipboard) and pi's external editor
 * shortcut (app.editor.external): long answers can be skimmed, searched, and
 * yanked with the editor's own motions, then Pi resumes where it left off.
 *
 * Text parts only, like /copy: thinking blocks and tool calls are omitted.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

type ProjectedMessage = ReturnType<
  ExtensionCommandContext["sessionManager"]["buildSessionProjection"]
>["messages"][number];

function messageText(message: ProjectedMessage): string {
  if (message.role !== "assistant") return "";
  let text = "";
  for (const part of message.content) {
    if (part.type === "text") text += part.text;
  }
  return text;
}

// Walk the active branch backwards and skip assistant turns that produced no
// prose (tool-only or aborted turns), so an empty tail still opens the last
// real answer.
export function lastAssistantText(messages: readonly ProjectedMessage[]): string | undefined {
  for (let index = messages.length - 1; index >= 0; index--) {
    const message = messages[index];
    if (!message) continue;
    const text = messageText(message);
    if (text.trim().length > 0) return text;
  }
  return undefined;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("last-message", {
    description: "Open the last assistant message in $EDITOR",
    handler: async (_args, ctx) => {
      const text = lastAssistantText(ctx.sessionManager.buildSessionProjection().messages);
      if (text === undefined) {
        ctx.ui.notify("No assistant message with text yet.", "warning");
        return;
      }
      await openInEditor(ctx, text, "last-message.md");
    },
  });
}

async function openInEditor(
  ctx: ExtensionCommandContext,
  text: string,
  fileName: string,
): Promise<void> {
  const editorCmd = process.env.VISUAL || process.env.EDITOR;
  if (ctx.mode !== "tui" || !editorCmd) {
    ctx.ui.notify("No editor available ($VISUAL/$EDITOR unset or non-TUI)", "warning");
    return;
  }

  await ctx.ui.custom<void>((tui, _theme, _kb, done) => {
    const directory = mkdtempSync(join(tmpdir(), "pi-extension-pager-last-message-"));
    const filePath = join(directory, fileName);
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
        try {
          rmSync(directory, { recursive: true, force: true });
        } catch {
          // Cleanup is best effort.
        }
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
