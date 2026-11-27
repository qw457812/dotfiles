// Pi's general MCP client requires a handshake before tools/call. This client
// supports stateless calls and preserves Retry-After for provider cooldowns.

import { Type, type Static } from "typebox";
import { Value } from "typebox/value";

import { HttpCallError, RequestCancelledError } from "./providers/types";

// Use Pi's supported versions. Stateless calls advertise the latest; after
// initialize, use the negotiated version (MCP 2025-06-18 lifecycle and transports).
export const SUPPORTED_PROTOCOL_VERSIONS = [
  "2025-11-25",
  "2025-06-18",
  "2025-03-26",
  "2024-11-05",
] as const;

export const LATEST_PROTOCOL_VERSION = SUPPORTED_PROTOCOL_VERSIONS[0];

class McpSchemaError extends Error {
  override name = "McpSchemaError";
}

export interface McpCallResult {
  text: string;
  isError: boolean;
  /** Provider-specific payload; the MCP envelope does not validate its shape. */
  structuredContent?: unknown;
}

export class McpRpcError extends Error {
  override name = "McpRpcError";
  readonly code: number | undefined;
  constructor(message: string, code?: number) {
    super(message);
    this.code = code;
  }
}

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

const McpResultSchema = Type.Object(
  {
    // Accept omitted envelope metadata for successful provider responses.
    id: Type.Optional(Type.Union([Type.String(), Type.Number(), Type.Null()])),
    jsonrpc: Type.Optional(Type.Literal("2.0")),
    result: Type.Object(
      {
        // Accept non-text blocks without validating fields this client does not consume.
        content: Type.Array(
          Type.Object(
            {
              type: Type.String(),
              text: Type.Optional(Type.String()),
            },
            { additionalProperties: true },
          ),
        ),
        isError: Type.Optional(Type.Boolean()),
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
    // Require the version marker to distinguish JSON-RPC errors from proxy JSON.
    jsonrpc: Type.Literal("2.0"),
    id: Type.Optional(Type.Union([Type.String(), Type.Number(), Type.Null()])),
    error: Type.Object(
      {
        code: Type.Integer(),
        message: Type.String(),
      },
      { additionalProperties: true },
    ),
  },
  { additionalProperties: true },
);

type McpError = Static<typeof McpErrorSchema>;

function extractText(data: unknown): McpCallResult | undefined {
  if (Value.Check(McpErrorSchema, data)) {
    const { error } = data as McpError;
    throw new McpRpcError(`MCP RPC error ${error.code}: ${error.message}`, error.code);
  }

  if (!Value.Check(McpResultSchema, data)) {
    throw new McpSchemaError("MCP response does not match expected schema");
  }

  const result = (data as McpResult).result;
  const isToolError = result.isError === true;

  for (const item of result.content) {
    if (item.type === "text" && item.text && item.text.length > 0) {
      return { text: item.text, isError: isToolError, structuredContent: result.structuredContent };
    }
  }

  // MCP 2025-06-18 permits empty content alongside structuredContent;
  // the recommendation to also send text does not make it mandatory.
  if (result.structuredContent !== undefined && result.structuredContent !== null) {
    return { text: "", isError: isToolError, structuredContent: result.structuredContent };
  }

  // Keep an empty tool error distinct from a successful result with no hits.
  if (isToolError) {
    return {
      text: "[Tool error: no text content available]",
      isError: true,
      structuredContent: result.structuredContent,
    };
  }

  return undefined;
}

// Skip non-JSON SSE data, but propagate errors from object-shaped payloads.
function tryParsePayload(raw: string): McpCallResult | undefined {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("{")) return undefined;
  const data = JSON.parse(trimmed); // Let SyntaxError propagate for malformed JSON
  return extractText(data);
}

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
  url: string;
  tool: string;
  args: Record<string, unknown>;
  /** Request timeout in milliseconds. */
  timeout?: number;
  headers?: Record<string, string>;
  signal?: AbortSignal;
  protocolVersion?: string;
}

export interface McpRequestOptions {
  url: string;
  /** JSON-RPC requests carry an id; notifications do not. */
  message: unknown;
  /** Name used in error messages, usually the tool or handshake phase. */
  label: string;
  /** Request timeout in milliseconds. */
  timeout?: number;
  headers?: Record<string, string>;
  signal?: AbortSignal;
  protocolVersion?: string;
}

export interface McpRawResponse {
  status: number;
  headers: Headers;
  body: string;
}

export const MAX_RESPONSE_BYTES = 256 * 1024;

class McpResponseTooLargeError extends Error {
  override name = "McpResponseTooLargeError";
}

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

// Initialization can use either JSON or SSE, just like a tool call.
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

// TinyFish also uses this raw path for handshake replies that aren't CallToolResult.
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

  // An abort listener does not fire for a signal that was already aborted.
  if (signal?.aborted) controller.abort();

  const onExternalAbort = () => controller.abort();
  signal?.addEventListener("abort", onExternalAbort, { once: true });

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        // MCP 2025-06-18 requires the header on requests after initialization.
        "MCP-Protocol-Version": protocolVersion,
        ...headers,
      },
      body: JSON.stringify(message),
      signal: controller.signal,
    });

    if (!response.ok) {
      // Keep raw diagnostics out of the model-facing error.
      let body: string;
      try {
        body = await readBoundedBody(response, label);
      } catch (err) {
        // Preserve HTTP status on oversize, but keep aborts classified as aborts.
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

// Keep isError in the result so providers can distinguish tool errors from no hits.
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
