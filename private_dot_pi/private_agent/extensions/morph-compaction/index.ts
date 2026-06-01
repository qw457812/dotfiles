// References:
// - Morph Compact API: https://docs.morphllm.com/sdk/components/compact
// - Pi compaction extensions: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/compaction.md#session_before_compact
// - Pi Morph compaction PR: https://github.com/earendil-works/pi/pull/2836
// - Rickicode Morph plugin: https://github.com/rickicode/pi-morphllm-plugin

/**
 * Morph Compaction Extension
 *
 * Uses Morph Compact to delete low-relevance lines from pi's compacted span.
 * This intentionally produces compressed transcript/context, not a rewritten
 * pi-style structured summary.
 *
 * API key resolution:
 *   MORPH_API_KEY environment variable
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@earendil-works/pi-coding-agent";
import { MorphClient, type CompactInput, type CompactResult } from "@morphllm/morphsdk";

const MORPH_MODEL = "morph-compactor";

// Morph docs: default 0.5 is a good start; long agent loops can use 0.3.
const COMPRESSION_RATIO = 0.3;

// Pi keeps recent context itself via firstKeptEntryId, so only compact the old span.
const PRESERVE_RECENT_MESSAGES = 0;

const DEFAULT_QUERY =
  "Keep the current user task, accepted constraints, current plan, recent decisions, file/code context, exact file paths, code symbols, commands, errors, files read or modified, and next actionable steps. Remove greetings, repetition, stale logs, obsolete alternatives, and irrelevant detours.";

function loadApiKey(): string | undefined {
  return process.env.MORPH_API_KEY?.trim() || undefined;
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

function buildInput(conversationText: string, previousSummary: string | undefined): string {
  const escapedConversationText = escapeMorphKeepContextTags(conversationText);
  const escapedPreviousSummary = previousSummary?.trim()
    ? escapeMorphKeepContextTags(previousSummary.trim())
    : undefined;

  if (!escapedPreviousSummary) return escapedConversationText;

  return [escapedPreviousSummary, escapedConversationText].join("\n\n");
}

async function compactWithAbort(
  morph: MorphClient,
  input: CompactInput,
  signal: AbortSignal,
): Promise<CompactResult> {
  if (signal.aborted) throw new Error("Morph compact aborted");

  let abortHandler: (() => void) | undefined;
  const abortPromise = new Promise<never>((_, reject) => {
    abortHandler = () => reject(new Error("Morph compact aborted"));
    signal.addEventListener("abort", abortHandler, { once: true });
  });

  try {
    return await Promise.race([morph.compact(input), abortPromise]);
  } finally {
    if (abortHandler) signal.removeEventListener("abort", abortHandler);
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async (event, ctx) => {
    const apiKey = loadApiKey();
    if (!apiKey) {
      ctx.ui.notify(
        "MORPH_API_KEY not found. Set it as an environment variable. Falling back to default compaction.",
        "warning",
      );
      return;
    }

    const { preparation, customInstructions, signal } = event;
    const {
      messagesToSummarize,
      turnPrefixMessages,
      tokensBefore,
      firstKeptEntryId,
      previousSummary,
    } = preparation;

    const allMessages = [...messagesToSummarize, ...turnPrefixMessages];
    if (allMessages.length === 0) return;

    const conversationText = serializeConversation(convertToLlm(allMessages));
    if (!conversationText.trim()) return;

    const input = buildInput(conversationText, previousSummary);
    const query = buildQuery(customInstructions);
    const inputChars = input.length;

    ctx.ui.notify(
      `Morph compact: compressing ${allMessages.length} messages (${tokensBefore.toLocaleString()} tokens, ${inputChars.toLocaleString()} chars)...`,
      "info",
    );

    const startTime = performance.now();

    try {
      const morph = new MorphClient({ apiKey });
      const data = await compactWithAbort(
        morph,
        {
          model: MORPH_MODEL,
          input,
          query,
          compressionRatio: COMPRESSION_RATIO,
          preserveRecent: PRESERVE_RECENT_MESSAGES,
          includeMarkers: true,
          includeLineRanges: false,
        },
        signal,
      );
      const summary = data.output;
      if (!summary?.trim()) {
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
