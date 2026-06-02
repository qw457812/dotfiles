// References:
// - Morph Compact API: https://docs.morphllm.com/sdk/components/compact
// - Pi compaction extensions: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/compaction.md#session_before_compact
// - Pi Morph compaction PR: https://github.com/earendil-works/pi/pull/2836
// - Rickicode Morph plugin: https://github.com/rickicode/pi-morphllm-plugin
// - Morph Claude Code plugin: https://github.com/morphllm/morph-claude-code-plugin
// - Morph OpenCode plugin: https://github.com/morphllm/opencode-morph-plugin

/**
 * Morph Compaction Extension
 *
 * Uses Morph Compact to delete low-relevance lines from pi's compacted span.
 * This intentionally produces compressed transcript/context, not a rewritten
 * pi-style structured summary.
 *
 * Enable switch:
 *   Disabled by default. Enable with `--morph-compact`, MORPH_COMPACT=1,
 *   or toggle at runtime with `/morph-compact on|off|status`.
 *
 * API key resolution:
 *   MORPH_API_KEY environment variable
 */

import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { ExtensionAPI, FileOperations, SessionEntry } from "@earendil-works/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@earendil-works/pi-coding-agent";
import { compact } from "./morph-client.ts";

const MORPH_MODEL = "morph-compactor";
const MORPH_COMPACT_FLAG = "morph-compact";
const MORPH_COMPACT_ENV = "MORPH_COMPACT";

// Morph docs: default 0.5 is a good start; long agent loops can use 0.3.
const COMPRESSION_RATIO = 0.3;

// Pi keeps recent context itself via firstKeptEntryId, so only compact the old span.
const PRESERVE_RECENT_MESSAGES = 0;

const DEFAULT_QUERY =
  "Keep the current user task, accepted constraints, current plan, recent decisions, file/code context, exact file paths, code symbols, commands, errors, files read or modified, and next actionable steps. Remove greetings, repetition, stale logs, obsolete alternatives, and irrelevant detours.";

function loadApiKey(): string | undefined {
  return process.env.MORPH_API_KEY?.trim() || undefined;
}

function loadMorphCompactDefault(): boolean {
  const value = process.env[MORPH_COMPACT_ENV]?.trim().toLowerCase();
  return value === "1" || value === "true" || value === "yes" || value === "on";
}

const MORPH_COMPACT_COMPLETIONS = [
  { value: "on", label: "on", description: "Enable Morph Compact" },
  { value: "off", label: "off", description: "Disable Morph Compact" },
  { value: "status", label: "status", description: "Show current Morph Compact state" },
];

function getMorphCompactCompletions(argumentPrefix: string) {
  const prefix = argumentPrefix.trimStart().toLowerCase();
  if (prefix.includes(" ")) return null;

  return MORPH_COMPACT_COMPLETIONS.filter((item) => item.value.startsWith(prefix));
}

function parseEnabledArg(args: string | undefined): boolean | "status" | undefined {
  const arg = args?.trim().split(/\s+/)[0]?.toLowerCase();
  switch (arg) {
    case "on":
    case "enable":
    case "enabled":
    case "true":
    case "1":
      return true;
    case "off":
    case "disable":
    case "disabled":
    case "false":
    case "0":
      return false;
    case "":
    case undefined:
    case "status":
      return "status";
    default:
      return undefined;
  }
}

function buildQuery(customInstructions: string | undefined): string {
  const focus = customInstructions?.trim();
  return focus ? `${DEFAULT_QUERY}\n\nAdditional focus: ${focus}` : DEFAULT_QUERY;
}

function escapeMorphKeepContextTags(text: string): string {
  return text.replace(
    /(^|\n)([ \t]*)<(\/?)keepContext>[ \t]*(?=\n|$)/g,
    "$1$2&lt;$3keepContext&gt;",
  );
}

function messageFromEntryForRawCompaction(entry: SessionEntry): AgentMessage | undefined {
  if (entry.type === "message") return entry.message;

  if (entry.type === "custom_message") {
    return {
      role: "custom",
      customType: entry.customType,
      content: entry.content,
      display: entry.display,
      details: entry.details,
      timestamp: new Date(entry.timestamp).getTime(),
    };
  }

  if (entry.type === "branch_summary") {
    return {
      role: "branchSummary",
      summary: entry.summary,
      fromId: entry.fromId,
      timestamp: new Date(entry.timestamp).getTime(),
    };
  }

  // Deliberately skip old compaction entries to avoid summary-of-summary drift.
  // Session metadata entries (labels, model/thinking changes, custom state, etc.)
  // do not participate in Pi's LLM context and should not pollute Morph input.
  return undefined;
}

function collectContextMessagesBeforeFirstKept(
  branchEntries: SessionEntry[],
  firstKeptEntryId: string,
): AgentMessage[] {
  const firstKeptIndex = branchEntries.findIndex((entry) => entry.id === firstKeptEntryId);
  if (firstKeptIndex < 0) return [];

  return branchEntries
    .slice(0, firstKeptIndex)
    .map(messageFromEntryForRawCompaction)
    .filter((message): message is AgentMessage => message !== undefined);
}

function toCompactMessages(messages: AgentMessage[]) {
  return convertToLlm(messages)
    .map((message) => ({
      role: message.role,
      content: escapeMorphKeepContextTags(serializeConversation([message])),
    }))
    .filter((message) => message.content.trim().length > 0);
}

function createEmptyFileOps(): FileOperations {
  return {
    read: new Set(),
    written: new Set(),
    edited: new Set(),
  };
}

function extractFileOps(message: AgentMessage, fileOps: FileOperations): void {
  if (message.role !== "assistant") return;

  for (const block of message.content) {
    if (block.type !== "toolCall") continue;

    const args = block.arguments as { path?: unknown } | undefined;
    const path = typeof args?.path === "string" ? args.path : undefined;
    if (!path) continue;

    if (block.name === "read") fileOps.read.add(path);
    if (block.name === "write") fileOps.written.add(path);
    if (block.name === "edit") fileOps.edited.add(path);
  }
}

function mergeFileOps(target: FileOperations, source: FileOperations): void {
  for (const path of source.read) target.read.add(path);
  for (const path of source.written) target.written.add(path);
  for (const path of source.edited) target.edited.add(path);
}

function computeFileLists(fileOps: FileOperations): {
  readFiles: string[];
  modifiedFiles: string[];
} {
  const modified = new Set([...fileOps.edited, ...fileOps.written]);
  const readFiles = [...fileOps.read].filter((path) => !modified.has(path)).sort();
  const modifiedFiles = [...modified].sort();
  return { readFiles, modifiedFiles };
}

function formatFileOperations(readFiles: string[], modifiedFiles: string[]): string {
  const sections: string[] = [];
  if (readFiles.length > 0) {
    sections.push(`<read-files>\n${readFiles.join("\n")}\n</read-files>`);
  }
  if (modifiedFiles.length > 0) {
    sections.push(`<modified-files>\n${modifiedFiles.join("\n")}\n</modified-files>`);
  }
  return sections.length > 0 ? `\n\n${sections.join("\n\n")}` : "";
}

function collectFileLists(messages: AgentMessage[], fallbackFileOps: FileOperations) {
  const fileOps = createEmptyFileOps();
  mergeFileOps(fileOps, fallbackFileOps);

  for (const message of messages) {
    extractFileOps(message, fileOps);
  }

  return computeFileLists(fileOps);
}

export default function (pi: ExtensionAPI) {
  pi.registerFlag(MORPH_COMPACT_FLAG, {
    description: "Enable Morph Compact during session compaction",
    type: "boolean",
    default: loadMorphCompactDefault(),
  });

  let morphCompactEnabled: boolean | undefined;

  function isMorphCompactEnabled(): boolean {
    return morphCompactEnabled ?? (pi.getFlag(MORPH_COMPACT_FLAG) as boolean) === true;
  }

  pi.registerCommand("morph-compact", {
    description: "Enable/disable Morph Compact (/morph-compact on|off|status)",
    getArgumentCompletions: getMorphCompactCompletions,
    handler: async (args, ctx) => {
      const enabled = parseEnabledArg(args);
      if (enabled === undefined) {
        ctx.ui.notify("Usage: /morph-compact on | off | status", "warning");
        return;
      }

      if (enabled !== "status") {
        morphCompactEnabled = enabled;
      }

      ctx.ui.notify(`Morph Compact is ${isMorphCompactEnabled() ? "enabled" : "disabled"}`, "info");
    },
  });

  pi.on("session_before_compact", async (event, ctx) => {
    if (!isMorphCompactEnabled()) return;

    const apiKey = loadApiKey();
    if (!apiKey) {
      ctx.ui.notify(
        "MORPH_API_KEY not found. Set it as an environment variable. Falling back to default compaction.",
        "warning",
      );
      return;
    }

    const { preparation, customInstructions, signal, branchEntries } = event;
    const { messagesToSummarize, turnPrefixMessages, tokensBefore, firstKeptEntryId, fileOps } =
      preparation;

    // Highest-fidelity mode: replay raw branch messages before Pi's kept boundary
    // instead of iteratively compacting previous summaries. Fall back to Pi's
    // prepared span if the kept entry cannot be found (e.g. older session data).
    const rawMessages = collectContextMessagesBeforeFirstKept(branchEntries, firstKeptEntryId);
    const messagesForMorph =
      rawMessages.length > 0 ? rawMessages : [...messagesToSummarize, ...turnPrefixMessages];
    if (messagesForMorph.length === 0) return;

    const compactMessages = toCompactMessages(messagesForMorph);
    if (compactMessages.length === 0) return;

    const query = buildQuery(customInstructions);
    const inputChars = compactMessages.reduce(
      (total, message) => total + message.content.length,
      0,
    );
    const { readFiles, modifiedFiles } = collectFileLists(messagesForMorph, fileOps);

    ctx.ui.notify(
      `Morph compact: compressing ${messagesForMorph.length} messages (${tokensBefore.toLocaleString()} tokens, ${inputChars.toLocaleString()} chars)...`,
      "info",
    );

    const startTime = performance.now();

    try {
      const data = await compact(
        apiKey,
        {
          model: MORPH_MODEL,
          messages: compactMessages,
          query,
          compressionRatio: COMPRESSION_RATIO,
          preserveRecent: PRESERVE_RECENT_MESSAGES,
          includeMarkers: true,
          includeLineRanges: false,
        },
        signal,
      );
      const summary = `${data.output.trimEnd()}${formatFileOperations(readFiles, modifiedFiles)}`;
      if (!summary.trim()) {
        if (!signal.aborted) {
          ctx.ui.notify(
            "Morph returned empty output, falling back to default compaction",
            "warning",
          );
        }
        return;
      }

      const durationMs = Math.round(performance.now() - startTime);
      const ratio = inputChars > 0 ? ((summary.length / inputChars) * 100).toFixed(1) : "N/A";

      ctx.ui.notify(
        `Morph compact complete: ${inputChars.toLocaleString()} → ${summary.length.toLocaleString()} chars (${ratio}%) in ${durationMs}ms`,
        "info",
      );

      return {
        compaction: {
          summary,
          firstKeptEntryId,
          tokensBefore,
          details: {
            provider: "morph",
            endpoint: "/v1/compact",
            compressionRatio: COMPRESSION_RATIO,
            messageCount: compactMessages.length,
            readFiles,
            modifiedFiles,
            usage: data.usage,
          },
        },
      };
    } catch (error) {
      if (signal.aborted) return;
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Morph compact failed: ${message}. Falling back to default.`, "error");
      return;
    }
  });
}
