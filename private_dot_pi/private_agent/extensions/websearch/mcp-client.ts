/**
 * Lightweight MCP-over-HTTP client.
 *
 * Two entry points over the same transport (timeout, abort, 429/Retry-After
 * mapping):
 * - `mcpRequest` posts one raw JSON-RPC message and returns the HTTP response
 *   (status, headers, body) — protocol phases such as TinyFish's `initialize`
 *   handshake and its bodyless `notifications/initialized` acknowledgement.
 * - `mcpCall` posts a `tools/call` and parses the result (plain JSON or SSE).
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

import { HttpCallError, RequestCancelledError } from "./providers/types";

/**
 * Protocol versions this client implements — pi's own MCP client list
 * (packages/mcp/src/protocol/types.ts). `LATEST` is what stateless requests
 * advertise; a provider that runs `initialize` advertises the negotiated
 * version instead, after validating it against this list.
 *
 * MCP 2025-06-18 lifecycle: the client MUST send a version it supports, the
 * server answers with a version it supports, and the client SHOULD disconnect
 * when the answer is unsupported. Transports: the client MUST send
 * `MCP-Protocol-Version` on subsequent requests and SHOULD send the
 * negotiated version.
 *
 * Sources: specification/2025-06-18/basic/lifecycle#version-negotiation and
 * specification/2025-06-18/basic/transports#protocol-version-header
 */
export const SUPPORTED_PROTOCOL_VERSIONS = [
  "2025-11-25",
  "2025-06-18",
  "2025-03-26",
  "2024-11-05",
] as const;

export const LATEST_PROTOCOL_VERSION = SUPPORTED_PROTOCOL_VERSIONS[0];

/** Error thrown when MCP response JSON doesn't match the expected schema. */
class McpSchemaError extends Error {
  override name = "McpSchemaError";
}

export interface McpCallResult {
  /** The text content returned by the MCP tool. */
  text: string;
  /** Whether the tool reported an execution error (isError: true). */
  isError: boolean;
  /**
   * Raw structuredContent from the MCP result (spec: optional structured
   * output object). Providers such as Parallel use it instead of text.
   * Unvalidated here — providers validate their own response shape.
   */
  structuredContent?: unknown;
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

/**
 * Thrown when a request exceeds its timeout. Typed so callers can tell a
 * timeout from user cancellation (`RequestCancelledError`) without matching
 * message text.
 */
export class McpTimeoutError extends Error {
  override name = "McpTimeoutError";
  constructor(
    message: string,
    readonly label: string,
    readonly timeoutMs: number,
  ) {
    super(message);
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
        structuredContent: Type.Optional(Type.Unknown()),
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
      return { text: item.text, isError: isToolError, structuredContent: result.structuredContent };
    }
  }

  // 4. Structured-only response (no content[].text): preserve structuredContent
  // for providers that parse it (Parallel). Per MCP 2025-06-18, `content` is
  // required but has no minItems (empty arrays are schema-valid) and
  // `structuredContent` is optional; servers SHOULD also serialize structured
  // content as a TextContent block, but structured-only responses remain
  // schema-valid — dropping them here would silently lose data for responses
  // the protocol permits.
  if (result.structuredContent !== undefined && result.structuredContent !== null) {
    return { text: "", isError: isToolError, structuredContent: result.structuredContent };
  }

  // When isError is true but no text content exists (e.g. only image/audio
  // blocks, empty array, or a structured-only response), return a fallback so
  // the caller surfaces the error to the LLM for self-correction. Returning
  // undefined would cause the caller to show "No search results found" and set
  // isError=false, violating MCP spec: "Clients SHOULD provide tool execution
  // errors to language models to enable self-correction."
  if (isToolError) {
    return {
      text: "[Tool error: no text content available]",
      isError: true,
      structuredContent: result.structuredContent,
    };
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
  /** MCP protocol version for the MCP-Protocol-Version header (default: LATEST_PROTOCOL_VERSION) */
  protocolVersion?: string;
}

/** One JSON-RPC message posted to an MCP endpoint, with its raw response. */
export interface McpRequestOptions {
  /** Remote MCP endpoint URL */
  url: string;
  /** Single JSON-RPC request or notification (notifications carry no `id`) */
  message: unknown;
  /** Name used in error messages (usually the tool name or phase) */
  label: string;
  /** Request timeout in ms (default 25000) */
  timeout?: number;
  /** Extra headers (e.g. Authorization, Mcp-Session-Id) */
  headers?: Record<string, string>;
  /** AbortSignal for cancellation */
  signal?: AbortSignal;
  /** MCP protocol version for the MCP-Protocol-Version header (default: LATEST_PROTOCOL_VERSION) */
  protocolVersion?: string;
}

export interface McpRawResponse {
  status: number;
  /**
   * Response headers. Carries `Mcp-Session-Id` when the server assigns a
   * session during initialization (MCP 2025-06-18 session management).
   */
  headers: Headers;
  body: string;
}

/** Cap on a single MCP response body (mirrors v2's MAX_RESPONSE_BYTES). */
export const MAX_RESPONSE_BYTES = 256 * 1024;

/** Thrown when a response body exceeds MAX_RESPONSE_BYTES. */
class McpResponseTooLargeError extends Error {
  override name = "McpResponseTooLargeError";
}

/**
 * Read a response body while enforcing MAX_RESPONSE_BYTES, so a broken or
 * hostile endpoint cannot make the extension buffer an unbounded body.
 * Cancels the stream as soon as the cap is crossed.
 */
async function readBoundedBody(response: Response, label: string): Promise<string> {
  const exceeded = () =>
    new McpResponseTooLargeError(`${label} response exceeded ${MAX_RESPONSE_BYTES} bytes`);

  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > MAX_RESPONSE_BYTES) {
    await response.body?.cancel().catch(() => {});
    throw exceeded();
  }
  if (!response.body) return "";

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let body = "";
  let bytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_RESPONSE_BYTES) {
        await reader.cancel().catch(() => {});
        throw exceeded();
      }
      body += decoder.decode(value, { stream: true });
    }
    return body + decoder.decode();
  } finally {
    reader.releaseLock();
  }
}

/**
 * Return the first JSON-RPC envelope from a body that is either a plain JSON
 * object or an SSE stream. MCP allows either content type for any request
 * (2025-06-18 transports), so protocol phases that are not tool calls parse
 * through this too.
 */
export function parseJsonRpcEnvelope(body: string): Record<string, unknown> | undefined {
  const candidates: string[] = [];
  const trimmed = body.trim();
  if (trimmed.startsWith("{")) candidates.push(trimmed);
  for (const line of body.split("\n")) {
    if (!line.startsWith("data:")) continue;
    const payload = line.slice(5).trimStart();
    if (payload.startsWith("{")) candidates.push(payload);
  }
  for (const candidate of candidates) {
    const data = JSON.parse(candidate); // SyntaxError propagates for malformed JSON
    if (data === null || typeof data !== "object" || Array.isArray(data)) continue;
    const envelope = data as Record<string, unknown>;
    if ("result" in envelope || "error" in envelope) return envelope;
  }
  return undefined;
}

/**
 * POST a single JSON-RPC message to an MCP endpoint and return the raw HTTP
 * response. Used directly for protocol phases that are not tool calls
 * (TinyFish's `initialize` / `notifications/initialized` handshake), where the
 * response is either not a CallToolResult or is a bodyless 2xx acknowledgement.
 *
 * Throws on timeout, user cancellation, network error, or non-2xx status
 * (`HttpCallError`, carrying Retry-After so 429s drive the selection cooldown).
 */
export async function mcpRequest(options: McpRequestOptions): Promise<McpRawResponse> {
  const {
    url,
    message,
    label,
    timeout = 25_000,
    headers = {},
    signal,
    protocolVersion = LATEST_PROTOCOL_VERSION,
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
        // MCP-Protocol-Version header on all subsequent requests." Default is
        // the latest version this client supports (the spec's 2025-03-26
        // fallback applies to servers that receive no header at all). All
        // mirrored endpoints accept it; an older server that does not must
        // answer 400, which surfaces as HttpCallError instead of silently
        // degrading.
        "MCP-Protocol-Version": protocolVersion,
        ...headers,
      },
      body: JSON.stringify(message),
      signal: controller.signal,
    });

    if (!response.ok) {
      // Read body for diagnostics but don't include raw response in the
      // error message visible to the LLM — it may contain sensitive data.
      // A body over the cap is reported as such instead of replacing the
      // HTTP failure with a size failure.
      let body: string;
      try {
        body = await readBoundedBody(response, label);
      } catch (err) {
        // Only the size cap is recoverable here: a cancelled or timed-out
        // body read must reach the outer catch so it keeps its classification
        // (and does not turn a 429 into a cooldown).
        if (!(err instanceof McpResponseTooLargeError)) throw err;
        body = `[body exceeded ${MAX_RESPONSE_BYTES} bytes]`;
      }
      console.error(`[mcp] ${label} HTTP ${response.status}: ${body.slice(0, 500)}`);
      throw new HttpCallError(
        `MCP request to ${label} failed: HTTP ${response.status} ${response.statusText}`,
        response.status,
        response.headers.get("retry-after") ?? undefined,
      );
    }

    return {
      status: response.status,
      headers: response.headers,
      body: await readBoundedBody(response, label),
    };
  } catch (err: any) {
    if (err.name === "AbortError") {
      // Distinguish user cancellation from timeout (mirrors OpenCode's Effect timeoutOrElse)
      if (signal?.aborted) {
        throw new RequestCancelledError(`MCP request to ${label} was cancelled`);
      }
      throw new McpTimeoutError(
        `MCP request to ${label} timed out after ${timeout}ms`,
        label,
        timeout,
      );
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
    signal?.removeEventListener("abort", onExternalAbort);
  }
}

/**
 * Call a remote MCP endpoint via HTTP POST and return the result.
 *
 * Supports both plain JSON and SSE response formats.
 * Returns undefined when the result carries neither text content nor
 * structuredContent. Structured-only responses (content: [] with
 * structuredContent) return { text: "", structuredContent } — per MCP
 * 2025-06-18, `content` is required but may be empty, so they are
 * schema-valid and must not be treated as empty results.
 * Throws on timeout, user cancellation, network error, JSON-RPC protocol error,
 * or schema mismatch.
 *
 * When the tool reports an execution error (isError: true), the result is
 * returned (not thrown) so the caller can surface the error content to the
 * LLM for self-correction, per the MCP specification.
 */
export async function mcpCall(options: McpCallOptions): Promise<McpCallResult | undefined> {
  const { url, tool, args, timeout, headers, signal, protocolVersion } = options;
  const { body } = await mcpRequest({
    url,
    label: tool,
    message: buildRequest(tool, args),
    timeout,
    headers,
    signal,
    protocolVersion,
  });
  return parseResponse(body);
}
