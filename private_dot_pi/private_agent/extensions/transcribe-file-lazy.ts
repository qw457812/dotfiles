/**
 * Lazy-enable the pi-voice `transcribe_file` tool.
 *
 * pi-voice registers `transcribe_file` and relies on Pi's startup behavior,
 * which activates every extension tool. This extension keeps it registered but
 * out of `pi.getActiveTools()` unless the session proves it needs it, so a
 * normal coding session never pays for the tool schema, prompt snippet, or
 * guidelines.
 *
 * Enabling signals:
 * - The active branch contains a historical assistant `toolCall` for
 *   `transcribe_file`. `session_start` and `session_tree` re-evaluate this on
 *   restore.
 * - `/transcribe-on` enables the tool explicitly for the current run.
 *
 * Rejected signals: prompt or workspace scanning, pi-voice's own `/transcribe`
 * and `/voice-settings` commands (opening settings does not prove transcription
 * work), and custom branch state (tool-call history is already a sufficient
 * restore proof).
 *
 * Once enabled during a run, this extension never disables the tool again
 * (one-way). A restored branch can show earlier transcribe_file calls, and
 * hiding the tool afterward would contradict that visible history. Disabling is
 * a user-initiated action owned by `/tools`, which rewrites the active set after
 * this extension's restore handlers run.
 *
 * The tool's execution behavior is unchanged; only its active-set membership
 * changes.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const TRANSCRIBE_FILE_TOOL = "transcribe_file";

function branchHasTranscribeFileToolCall(ctx: ExtensionContext): boolean {
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message") continue;
    const message = entry.message;
    if (message.role !== "assistant" || !Array.isArray(message.content)) continue;

    for (const block of message.content) {
      if (block.type === "toolCall" && block.name === TRANSCRIBE_FILE_TOOL) return true;
    }
  }
  return false;
}

export default function (pi: ExtensionAPI): void {
  let transcribeFileToolEnabled = false;

  function setTranscribeFileToolEnabled(enabled: boolean): void {
    // One-way: a branch restore may not hide a tool this run already exposed.
    if (!enabled && transcribeFileToolEnabled) return;

    // Stay inert when pi-voice is absent or its tool is filtered out.
    const registered = new Set(pi.getAllTools().map((tool) => tool.name));
    if (!registered.has(TRANSCRIBE_FILE_TOOL)) return;

    const activeTools = new Set(pi.getActiveTools());
    const activeToolCountBefore = activeTools.size;

    if (enabled) {
      transcribeFileToolEnabled = true;
      activeTools.add(TRANSCRIBE_FILE_TOOL);
    } else {
      activeTools.delete(TRANSCRIBE_FILE_TOOL);
    }

    if (activeTools.size !== activeToolCountBefore) pi.setActiveTools(Array.from(activeTools));
  }

  function restoreTranscribeFileTool(ctx: ExtensionContext): void {
    setTranscribeFileToolEnabled(branchHasTranscribeFileToolCall(ctx));
  }

  pi.on("session_start", async (_event, ctx) => restoreTranscribeFileTool(ctx));
  pi.on("session_tree", async (_event, ctx) => restoreTranscribeFileTool(ctx));

  pi.registerCommand("transcribe-on", {
    description: "Enable the transcribe_file tool for this run",
    handler: async (_args, ctx) => {
      if (transcribeFileToolEnabled) {
        ctx.ui.notify("transcribe_file is already enabled", "info");
        return;
      }
      setTranscribeFileToolEnabled(true);
      ctx.ui.notify("transcribe_file enabled for this run", "info");
    },
  });
}
