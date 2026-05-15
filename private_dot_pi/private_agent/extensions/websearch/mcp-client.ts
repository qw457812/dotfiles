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
 *
 * Error detection (prevents silent failures on HTTP 200):
 * - JSON-RPC error envelope (error.code + error.message) → McpRpcError (throw)
 * - Tool execution error (result.isError === true) → returned as McpCallResult with isError: true
 * - Schema mismatch → McpSchemaError (throw)
 */

import { Type, type Static } from "typebox";
import { Value } from "typebox/value";

/** Error thrown when MCP response JSON doesn't match the expected schema. */
class McpSchemaError extends Error {
  override name = "McpSchemaError";
}

export interface McpCallResult {
  /** The text content returned by the MCP tool. */
  text: string;
  /** Whether the tool reported an execution error (isError: true). */
  isError: boolean;
}

/** Error thrown when the MCP server returns a JSON-RPC level error. */
export class McpRpcError extends Error {
  override name = "McpRpcError";
  readonly code: number | undefined;
  constructor(message: string, code?: number) {
    super(message);
    this.code = code;
  }
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

const McpResultSchema = Type.Object(
  {
    // JSON-RPC 2.0 spec §5.1: Response objects MUST contain an `id` member.
    // We match the request id (number) — present on all valid JSON-RPC responses
    // so servers may include `id`, `jsonrpc` etc in the outer envelope.
    id: Type.Optional(Type.Union([Type.String(), Type.Number(), Type.Null()])),
    jsonrpc: Type.Optional(Type.Literal("2.0")),
    result: Type.Object(
      {
        // Spec: CallToolResult.content is ContentBlock[] which includes
        // TextContent, ImageContent, AudioContent, ResourceLink, EmbeddedResource.
        // We use a permissive schema since we only extract text content;
        // non-text blocks are silently skipped during extraction.
        content: Type.Array(
          Type.Object(
            {
              type: Type.String(),
              // text is only present on TextContent; other ContentBlock types
              // have different fields (data/mimeType for image/audio, etc.)
              text: Type.Optional(Type.String()),
            },
            { additionalProperties: true },
          ),
        ),
        isError: Type.Optional(Type.Boolean()),
        // structuredContent and _meta are optional per spec.
      },
      { additionalProperties: true },
    ),
  },
  { additionalProperties: true },
);

type McpResult = Static<typeof McpResultSchema>;

const McpErrorSchema = Type.Object(
  {
    // JSON-RPC 2.0 spec: every response MUST include "jsonrpc": "2.0".
    // Without this field, non-RPC JSON errors (e.g. CDN/proxy rate limits like
    // {"error": {"code": 429, "message": "Rate limit exceeded"}}) would be
    // misclassified as MCP protocol errors, preventing the LLM from seeing
    // the error and self-correcting.
    jsonrpc: Type.Literal("2.0"),
    // JSON-RPC 2.0 spec §5.1: Response objects MUST contain an `id` member
    // matching the Request's `id`, or `null` for parse errors.
    id: Type.Optional(Type.Union([Type.String(), Type.Number(), Type.Null()])),
    error: Type.Object(
      {
        // Spec: "Error codes MUST be integers"
        code: Type.Integer(),
        message: Type.String(),
      },
      { additionalProperties: true },
    ),
  },
  { additionalProperties: true },
);

type McpError = Static<typeof McpErrorSchema>;

/**
 * Validate parsed JSON and extract text from result.content[].
 *
 * Checks two error conditions in order before extracting text:
 * 1. JSON-RPC error envelope (error.code + error.message) → McpRpcError (throw)
 * 2. Schema mismatch → McpSchemaError (throw)
 *
 * For valid result responses:
 * - isError === true: returns { text, isError: true } so callers can surface
 *   the error content to the LLM for self-correction (per MCP spec:
 *   "Clients SHOULD provide tool execution errors to language models
 *   to enable self-correction.")
 * - isError absent/false: returns { text, isError: false }
 *
 * JSON-RPC errors and schema mismatches throw because they indicate
 * protocol-level failures that are not actionable by the LLM.
 */
function extractText(data: unknown): McpCallResult | undefined {
  // 1. Check for JSON-RPC level error (protocol error → throw)
  if (Value.Check(McpErrorSchema, data)) {
    const { error } = data as McpError;
    throw new McpRpcError(`MCP RPC error ${error.code}: ${error.message}`, error.code);
  }

  // 2. Check schema match (must have result.content[])
  if (!Value.Check(McpResultSchema, data)) {
    throw new McpSchemaError("MCP response does not match expected schema");
  }

  const result = (data as McpResult).result;
  const isToolError = result.isError === true;

  // 3. Extract first non-empty text
  for (const item of result.content) {
    if (item.type === "text" && item.text && item.text.length > 0) {
      return { text: item.text, isError: isToolError };
    }
  }

  // When isError is true but no text content exists (e.g. only image/audio
  // blocks or empty array), return a fallback so the caller surfaces the
  // error to the LLM for self-correction. Returning undefined would cause
  // the caller to show "No search results found" and set isError=false,
  // violating MCP spec: "Clients SHOULD provide tool execution errors to
  // language models to enable self-correction."
  if (isToolError) {
    return { text: "[Tool error: no text content available]", isError: true };
  }

  return undefined;
}

/**
 * Try to parse a single JSON string as an MCP result.
 * Returns undefined if the string doesn't look like JSON or contains no extractable result.
 * Throws on malformed JSON that *looks* like JSON (starts with `{`) but fails parse —
 * callers propagate the failure (no per-line catch).
 */
function tryParsePayload(raw: string): McpCallResult | undefined {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("{")) return undefined;
  const data = JSON.parse(trimmed); // Let SyntaxError propagate for malformed JSON
  return extractText(data);
}

/**
 * Parse the HTTP response body — supports plain JSON and SSE formats.
 * Returns undefined when no valid result is found (mirrors OpenCode).
 *
 * For direct JSON (non-SSE): schema mismatch throws (fail-fast) — a
 * valid JSON-RPC error response should not silently become "No results".
 *
 * For SSE: schema mismatch on any data: line fails fast (mirrors OpenCode's
 * yield* parsePayload which propagates decode failures immediately).
 */
function parseResponse(body: string): McpCallResult | undefined {
  const trimmed = body.trim();

  if (trimmed) {
    const direct = tryParsePayload(trimmed);
    if (direct) return direct;
  }

  for (const line of body.split("\n")) {
    if (!line.startsWith("data:")) continue;
    const result = tryParsePayload(line.slice(5).trimStart());
    if (result) return result;
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
  /** MCP protocol version for the MCP-Protocol-Version header (default: "2025-03-26") */
  protocolVersion?: string;
}

/**
 * Call a remote MCP endpoint via HTTP POST and return the result.
 *
 * Supports both plain JSON and SSE response formats.
 * Returns undefined when no valid text content is found.
 * Throws on timeout, user cancellation, network error, JSON-RPC protocol error,
 * or schema mismatch.
 *
 * When the tool reports an execution error (isError: true), the result is
 * returned (not thrown) so the caller can surface the error content to the
 * LLM for self-correction, per the MCP specification.
 */
export async function mcpCall(options: McpCallOptions): Promise<McpCallResult | undefined> {
  const {
    url,
    tool,
    args,
    timeout = 25_000,
    headers = {},
    signal,
    protocolVersion = "2025-03-26",
  } = options;

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
        // Spec 2025-06-18: "If using HTTP, the client MUST include the
        // MCP-Protocol-Version header on all subsequent requests."
        // Forward-compatible with 2025-03-26 servers (which ignore unknown
        // headers per HTTP spec). Default is the 2025-03-26 fallback per spec.
        "MCP-Protocol-Version": protocolVersion,
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
