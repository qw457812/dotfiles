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
 * API key resolution:
 *   MORPH_API_KEY environment variable
 */

import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { ExtensionAPI, FileOperations, SessionEntry } from "@earendil-works/pi-coding-agent";
import { convertToLlm, serializeConversation } from "@earendil-works/pi-coding-agent";

const MORPH_COMPACT_URL = "https://api.morphllm.com/v1/compact";
const MORPH_COMPACT_TIMEOUT_MS = 120_000;

type CompactMessageInput = {
  role: string;
  content: string;
};

type CompactInput = {
  model: string;
  messages: CompactMessageInput[];
  query: string;
  compressionRatio: number;
  preserveRecent: number;
  includeMarkers: boolean;
  includeLineRanges: boolean;
};

type CompactResult = {
  output: string;
  usage?: {
    input_tokens?: number;
    output_tokens?: number;
    compression_ratio?: number;
    processing_time_ms?: number;
  };
};

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

function toCompactMessages(messages: AgentMessage[]): CompactMessageInput[] {
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

// --- Retry logic, aligned with @morphllm/morphsdk@0.2.173 fetchWithRetry ---
// Source: @morphllm/morphsdk/dist/chunk-JXJBF6CV.js
//
// SDK defaults: maxRetries=3, initialDelay=1000, maxDelay=30000, backoffMultiplier=2
// Retries on: HTTP 429/503, network errors ECONNREFUSED/ETIMEDOUT/ENOTFOUND
//
// Aligned with SDK: the overall timeout wraps the entire retry loop.
// At 33k tok/s even 1M tokens finishes in ~30s, so 120s budget covers
// multiple attempts comfortably.

const RETRY_DEFAULTS = {
  maxRetries: 3,
  initialDelay: 1000,
  maxDelay: 30000,
  backoffMultiplier: 2,
  retryableStatuses: new Set([429, 503]),
  retryableErrorCodes: ["ECONNREFUSED", "ETIMEDOUT", "ENOTFOUND"],
} as const;

function sleep(ms: number, signal: AbortSignal): Promise<void> {
  const rejectWithReason = () => {
    const reason = signal.reason;
    return reason instanceof Error ? reason : new Error("Morph compact aborted");
  };
  if (signal.aborted) return Promise.reject(rejectWithReason());
  return new Promise((resolve, reject) => {
    const onAbort = () => {
      clearTimeout(timer);
      reject(rejectWithReason());
    };
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    signal.addEventListener("abort", onAbort, { once: true });
  });
}

function isRetryableNetworkError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  // Node.js undici fetch wraps network errors: error is TypeError("fetch failed"),
  // error.cause is the actual Error with .code (e.g. "ECONNREFUSED").
  // Also handle direct errors (non-fetch) where .code is on the error itself.
  const code =
    (error.cause as { code?: string } | undefined)?.code ??
    (error as { code?: string }).code;
  if (typeof code === "string") {
    return (RETRY_DEFAULTS.retryableErrorCodes as readonly string[]).includes(code);
  }
  // Fallback: check message for non-fetch errors that don't use .code
  return RETRY_DEFAULTS.retryableErrorCodes.some((c) => error.message?.includes(c));
}

function capRetryDelay(ms: number): number {
  return Math.min(ms, RETRY_DEFAULTS.maxDelay);
}

function increaseRetryDelay(delay: number): number {
  return delay * RETRY_DEFAULTS.backoffMultiplier;
}

function retryDelayFromHeader(response: Response, fallbackDelay: number): number {
  const retryAfter = response.headers.get("Retry-After");
  const parsed = retryAfter ? parseInt(retryAfter, 10) * 1000 : NaN;
  // Retry-After can be seconds (integer) or HTTP-date; parseInt on a date
  // returns NaN. Fall back to computed delay when unparseable.
  return Number.isFinite(parsed) ? capRetryDelay(parsed) : capRetryDelay(fallbackDelay);
}

async function fetchWithRetry(
  url: string,
  init: RequestInit,
  signal: AbortSignal,
): Promise<Response> {
  // Overall timeout wraps the entire retry loop (aligned with SDK's
  // withTimeout(fetchWithRetry(...), timeout) pattern).
  let delay: number = RETRY_DEFAULTS.initialDelay;
  const controller = new AbortController();
  const abortFromCaller = () => controller.abort(signal.reason);
  signal.addEventListener("abort", abortFromCaller, { once: true });
  const timeoutId = setTimeout(
    () => controller.abort(new Error(`Morph compact timed out after ${MORPH_COMPACT_TIMEOUT_MS}ms`)),
    MORPH_COMPACT_TIMEOUT_MS,
  );

  try {
    for (let attempt = 0; attempt <= RETRY_DEFAULTS.maxRetries; attempt++) {
      if (signal.aborted) throw new Error("Morph compact aborted");
      const hasRetryRemaining = attempt < RETRY_DEFAULTS.maxRetries;

      let response: Response;
      try {
        response = await fetch(url, { ...init, signal: controller.signal });
      } catch (error) {
        // Network error: retry if retryable
        if (isRetryableNetworkError(error) && hasRetryRemaining) {
          await sleep(capRetryDelay(delay), controller.signal);
          delay = increaseRetryDelay(delay);
          continue;
        }
        throw error;
      }

      // HTTP-level retry on 429 / 503 (aligned with SDK fetchWithRetry)
      if (RETRY_DEFAULTS.retryableStatuses.has(response.status) && hasRetryRemaining) {
        // Release response body so undici can reclaim the connection.
        await response.body?.cancel().catch(() => {});

        await sleep(retryDelayFromHeader(response, delay), controller.signal);
        delay = increaseRetryDelay(delay);
        continue;
      }

      return response;
    }

    throw new Error("Morph compact: max retries exceeded");
  } finally {
    clearTimeout(timeoutId);
    signal.removeEventListener("abort", abortFromCaller);
  }
}

async function compactWithRetry(
  apiKey: string,
  input: CompactInput,
  signal: AbortSignal,
): Promise<CompactResult> {
  if (signal.aborted) throw new Error("Morph compact aborted");

  const response = await fetchWithRetry(
    MORPH_COMPACT_URL,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: input.model,
        messages: input.messages,
        query: input.query,
        compression_ratio: input.compressionRatio,
        preserve_recent: input.preserveRecent,
        include_markers: input.includeMarkers,
        include_line_ranges: input.includeLineRanges,
      }),
    },
    signal,
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Morph compact returned ${response.status}: ${errorText}`);
  }

  const data = (await response.json()) as { output?: unknown; usage?: CompactResult["usage"] };
  if (typeof data.output !== "string") {
    throw new Error("Morph compact returned an unexpected response shape");
  }

  return {
    output: data.output,
    usage: data.usage,
  };
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
      const data = await compactWithRetry(
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
