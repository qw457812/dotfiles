// References:
// - Morph Compact API: https://docs.morphllm.com/sdk/components/compact
// - Retry logic aligned with @morphllm/morphsdk@0.2.173 fetchWithRetry
//   Source: @morphllm/morphsdk/dist/chunk-JXJBF6CV.js

/**
 * Morph Compact API client
 *
 * Handles HTTP calls to Morph's /v1/compact endpoint with retry logic
 * matching morphsdk's fetchWithRetry behaviour.
 */

const MORPH_COMPACT_URL = "https://api.morphllm.com/v1/compact";
const MORPH_COMPACT_TIMEOUT_MS = 120_000;

export type CompactMessageInput = {
  role: string;
  content: string;
};

export type CompactInput = {
  model: string;
  messages: CompactMessageInput[];
  query: string;
  compressionRatio: number;
  preserveRecent: number;
  includeMarkers: boolean;
  includeLineRanges: boolean;
};

export type CompactResult = {
  output: string;
  usage?: {
    input_tokens?: number;
    output_tokens?: number;
    compression_ratio?: number;
    processing_time_ms?: number;
  };
};

// --- Retry defaults, aligned with morphsdk ---
// SDK defaults: maxRetries=3, initialDelay=1000, maxDelay=30000, backoffMultiplier=2
// Retries on: HTTP 429/503, network errors ECONNREFUSED/ETIMEDOUT/ENOTFOUND
//
// The overall timeout wraps the entire retry loop.
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
    (error.cause as { code?: string } | undefined)?.code ?? (error as { code?: string }).code;
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
  let delay: number = RETRY_DEFAULTS.initialDelay;
  const controller = new AbortController();
  const abortFromCaller = () => controller.abort(signal.reason);
  signal.addEventListener("abort", abortFromCaller, { once: true });
  const timeoutId = setTimeout(
    () =>
      controller.abort(new Error(`Morph compact timed out after ${MORPH_COMPACT_TIMEOUT_MS}ms`)),
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
        if (isRetryableNetworkError(error) && hasRetryRemaining) {
          await sleep(capRetryDelay(delay), controller.signal);
          delay = increaseRetryDelay(delay);
          continue;
        }
        throw error;
      }

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

export async function compact(
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
