/**
 * Lightweight MCP-over-HTTP client.
 *
 * Sends JSON-RPC 2.0 `tools/call` requests to a remote MCP endpoint
 * and parses the response (plain JSON or SSE).
 *
 * Mirrors OpenCode's mcp-websearch.ts parsing logic:
 * - Direct JSON body: decode JSON-RPC envelope, extract result.content[].text
 * - SSE body: scan `data:` lines, parse each as JSON-RPC, return first with text
 * - TypeBox schema validation on parsed JSON (mirrors OpenCode's Effect Schema)
 */

import { Type, type Static } from "typebox";
import { Value } from "typebox/value";

/** Error thrown when MCP response JSON doesn't match the expected schema. */
class McpSchemaError extends Error {
  override name = "McpSchemaError";
}

function buildRequest(toolName: string, args: Record<string, unknown>) {
  return {
    jsonrpc: "2.0" as const,
    id: 1 as const,
    method: "tools/call" as const,
    params: {
      name: toolName,
      arguments: args,
    },
  };
}

// ---------------------------------------------------------------------------
// MCP JSON-RPC result schema (mirrors OpenCode's McpResult Schema.Struct)
// ---------------------------------------------------------------------------

const McpResultSchema = Type.Object({
  result: Type.Object({
    content: Type.Array(
      Type.Object({
        type: Type.String(),
        text: Type.String(),
      }),
    ),
  }),
});

type McpResult = Static<typeof McpResultSchema>;

/**
 * Validate parsed JSON against the MCP result schema and extract the first
 * non-empty text from result.content[].
 *
 * Mirrors OpenCode: uses schema validation (TypeBox ↔ Effect Schema),
 * requires both `type` and `text` as string fields.
 *
 * Throws on schema mismatch — a valid JSON-RPC response that doesn't
 * match the expected envelope (e.g., JSON-RPC error with HTTP 200) should
 * fail fast, not silently return undefined which becomes "No search results
 * found." Callers catch in SSE loops where non-matching frames are expected.
 */
function extractText(data: unknown): string | undefined {
  if (!Value.Check(McpResultSchema, data)) {
    throw new McpSchemaError("MCP response does not match expected schema");
  }
  const { content } = (data as McpResult).result;
  for (const item of content) {
    if (item.text.length > 0) return item.text;
  }
  return undefined;
}

/**
 * Try to parse a single JSON string as an MCP result.
 * Returns undefined if the string doesn't look like JSON or contains no text.
 * Throws on malformed JSON that *looks* like JSON (starts with `{`) but fails parse —
 * callers propagate the failure (no per-line catch).
 */
function tryParsePayload(raw: string): string | undefined {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("{")) return undefined;
  const data = JSON.parse(trimmed); // Let SyntaxError propagate for malformed JSON
  return extractText(data);
}

/**
 * Parse the HTTP response body — supports plain JSON and SSE formats.
 * Returns undefined when no valid text content is found (mirrors OpenCode).
 *
 * For direct JSON (non-SSE): schema mismatch throws (fail-fast) — a
 * valid JSON-RPC error response should not silently become "No results".
 *
 * For SSE: schema mismatch on any data: line fails fast (mirrors OpenCode's
 * yield* parsePayload which propagates decode failures immediately).
 */
function parseResponse(body: string): string | undefined {
  const trimmed = body.trim();

  if (trimmed) {
    const direct = tryParsePayload(trimmed);
    if (direct) return direct;
  }

  for (const line of body.split("\n")) {
    if (!line.startsWith("data: ")) continue;
    const text = tryParsePayload(line.substring(6));
    if (text) return text;
  }

  return undefined;
}

interface McpCallOptions {
  /** Remote MCP endpoint URL */
  url: string;
  /** MCP tool name (e.g. "web_search_exa") */
  tool: string;
  /** Arguments for the tool */
  args: Record<string, unknown>;
  /** Request timeout in ms (default 25000) */
  timeout?: number;
  /** Extra headers (e.g. Authorization) */
  headers?: Record<string, string>;
  /** AbortSignal for cancellation */
  signal?: AbortSignal;
}

/**
 * Call a remote MCP endpoint via HTTP POST and return the text result.
 *
 * Supports both plain JSON and SSE response formats.
 * Returns undefined when no valid text content is found.
 * Throws on timeout, user cancellation, network error, or malformed JSON.
 */
export async function mcpCall(options: McpCallOptions): Promise<string | undefined> {
  const { url, tool, args, timeout = 25_000, headers = {}, signal } = options;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  // If signal is already aborted on entry, abort immediately.
  // addEventListener("abort", ...) won't fire for a pre-aborted signal
  // since the event already dispatched, causing fetch to run uncanceled.
  //
  // Note: a theoretical race exists between this check and addEventListener
  // below (signal could fire in between). In single-threaded Node.js this is
  // practically impossible, and the timeout provides a backstop regardless.
  if (signal?.aborted) controller.abort();

  // Link external signal so user-abort also cancels
  const onExternalAbort = () => controller.abort();
  signal?.addEventListener("abort", onExternalAbort, { once: true });

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        ...headers,
      },
      body: JSON.stringify(buildRequest(tool, args)),
      signal: controller.signal,
    });

    if (!response.ok) {
      // Read body for diagnostics but don't include raw response in the
      // error message visible to the LLM — it may contain sensitive data.
      const body = await response.text();
      console.error(`[mcp] ${tool} HTTP ${response.status}: ${body.slice(0, 500)}`);
      throw new Error(
        `MCP request to ${tool} failed: HTTP ${response.status} ${response.statusText}`,
      );
    }

    const body = await response.text();
    return parseResponse(body);
  } catch (err: any) {
    if (err.name === "AbortError") {
      // Distinguish user cancellation from timeout (mirrors OpenCode's Effect timeoutOrElse)
      if (signal?.aborted) {
        throw new Error(`MCP request to ${tool} was cancelled`);
      }
      throw new Error(`MCP request to ${tool} timed out after ${timeout}ms`);
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
    signal?.removeEventListener("abort", onExternalAbort);
  }
}
