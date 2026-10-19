/**
 * TinyFish search provider — calls the remote TinyFish MCP endpoint.
 *
 * Endpoint: https://agent.tinyfish.ai/mcp
 * Auth: X-API-Key via TINYFISH_API_KEY, otherwise X-TinyFish-Access-Mode: keyless.
 * Tool name: search
 *
 * Mirrors OpenCode v2's packages/core/src/plugin/websearch/tinyfish.ts:
 * - Keyed requests must first run the MCP session handshake (`initialize` →
 *   `notifications/initialized`) and present the returned `Mcp-Session-Id`;
 *   without it the server answers 400 "Missing required Mcp-Session-Id
 *   header" (spec: a server requiring a session SHOULD reply 400). Keyless
 *   requests are stateless and skip the handshake — their `initialize` returns
 *   no session header at all, so running it would fail on the missing header.
 * - Results are JSON inside MCP text content: {query, results: [{url, title,
 *   snippet}]}, mapped to url/title/content.
 * - The protocol version is negotiated in `initialize` and validated against
 *   pi's supported list (see mcp-client); the negotiated value is advertised
 *   on the notification and on `search`.
 * - A session is rebuilt for every search and never terminated: v2 does the
 *   same (the 404 "Session not found" re-initialize path is effectively
 *   unreachable when the session id is seconds old).
 */

import { VERSION } from "@earendil-works/pi-coding-agent";
import {
  LATEST_PROTOCOL_VERSION,
  McpTimeoutError,
  mcpCall,
  mcpRequest,
  parseJsonRpcEnvelope,
  SUPPORTED_PROTOCOL_VERSIONS,
} from "../mcp-client";
import type {
  ProviderCallContext,
  WebSearchInput,
  WebSearchProvider,
  WebSearchResult,
} from "./types";

const TINYFISH_ENDPOINT = "https://agent.tinyfish.ai/mcp";

/** One budget for initialize + initialized notification (v2's 25s scope). */
const INIT_TIMEOUT_MS = 25_000;

const SEARCH_TIMEOUT_MS = 25_000;

const PI_VERSION = `pi/${VERSION}`;

interface TinyFishSearchResponse {
  results: Array<{
    url: string;
    title?: string;
    snippet?: string;
  }>;
}

function getTinyFishHeaders(apiKey: string | undefined): Record<string, string> {
  const headers: Record<string, string> = {
    "User-Agent": PI_VERSION,
  };
  if (apiKey) {
    headers["X-API-Key"] = apiKey;
  } else {
    headers["X-TinyFish-Access-Mode"] = "keyless";
  }
  return headers;
}

/**
 * Validate the InitializeResult and return its `protocolVersion`.
 *
 * The handshake previously ignored the response body; a JSON-RPC error
 * envelope or a missing version would surface only as a confusing "no
 * Mcp-Session-Id" error. Protocol-level corruption fails fast here instead.
 * The body is either plain JSON or SSE (both are legal for any request), so
 * it goes through the shared envelope parser.
 */
function parseInitializeResult(body: string): string {
  const envelope = parseJsonRpcEnvelope(body);
  if (envelope === undefined) {
    throw new Error("TinyFish MCP initialize returned no JSON-RPC payload");
  }
  const error = envelope.error;
  if (error !== null && typeof error === "object") {
    const message = (error as { message?: unknown }).message;
    throw new Error(
      `TinyFish MCP initialize failed: ${typeof message === "string" ? message : "unknown error"}`,
    );
  }
  const result = envelope.result;
  const version =
    result !== null && typeof result === "object"
      ? (result as { protocolVersion?: unknown }).protocolVersion
      : undefined;
  if (typeof version !== "string" || version.length === 0) {
    throw new Error("TinyFish MCP initialize returned no protocolVersion");
  }
  return version;
}

/**
 * Run the MCP session handshake: negotiate the protocol version, capture the
 * server's `Mcp-Session-Id`, and send the `initialized` notification.
 *
 * The notification is acknowledged with an empty 204 (the spec says 202), so
 * it goes through `mcpRequest`, which only checks the HTTP status instead of
 * trying to parse a CallToolResult.
 */
async function initialize(
  headers: Record<string, string>,
  signal: AbortSignal | undefined,
): Promise<{ session: string; protocolVersion: string }> {
  const deadline = Date.now() + INIT_TIMEOUT_MS;
  const remaining = () => Math.max(1, deadline - Date.now());

  try {
    const init = await mcpRequest({
      url: TINYFISH_ENDPOINT,
      label: "TinyFish initialize",
      message: {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: LATEST_PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: { name: "pi", version: VERSION },
        },
      },
      timeout: remaining(),
      headers,
      signal,
      protocolVersion: LATEST_PROTOCOL_VERSION,
    });

    const negotiated = parseInitializeResult(init.body);
    if (!(SUPPORTED_PROTOCOL_VERSIONS as readonly string[]).includes(negotiated)) {
      throw new Error(`TinyFish MCP server selected unsupported protocol version ${negotiated}`);
    }

    const session = init.headers.get("mcp-session-id");
    if (!session) {
      throw new Error("TinyFish MCP initialize did not return an Mcp-Session-Id header");
    }

    await mcpRequest({
      url: TINYFISH_ENDPOINT,
      label: "TinyFish initialized notification",
      message: { jsonrpc: "2.0", method: "notifications/initialized" },
      timeout: remaining(),
      headers: { ...headers, "Mcp-Session-Id": session },
      signal,
      protocolVersion: negotiated,
    });

    return { session, protocolVersion: negotiated };
  } catch (err) {
    // One budget covers the whole handshake, like v2's single
    // Effect.timeoutOrElse: either leg timing out reports the same message.
    if (err instanceof McpTimeoutError) {
      throw new Error("TinyFish initialize request timed out", { cause: err });
    }
    throw err;
  }
}

function parseTinyFishResults(text: string): WebSearchResult[] {
  const response = JSON.parse(text) as TinyFishSearchResponse;
  if (!Array.isArray(response?.results)) {
    throw new Error("TinyFish response missing results");
  }
  return response.results.map((item) => ({
    url: item.url,
    ...(item.title ? { title: item.title } : {}),
    ...(item.snippet ? { content: item.snippet } : {}),
  }));
}

export const tinyfishProvider: WebSearchProvider = {
  id: "tinyfish",
  label: "TinyFish",
  async execute(input: WebSearchInput, ctx: ProviderCallContext): Promise<WebSearchResult[]> {
    const apiKey = process.env.TINYFISH_API_KEY;
    const headers = getTinyFishHeaders(apiKey);
    const handshake = apiKey ? await initialize(headers, ctx.signal) : undefined;

    const result = await mcpCall({
      url: TINYFISH_ENDPOINT,
      tool: "search",
      args: { query: input.query },
      timeout: SEARCH_TIMEOUT_MS,
      headers:
        handshake === undefined ? headers : { ...headers, "Mcp-Session-Id": handshake.session },
      signal: ctx.signal,
      protocolVersion: handshake?.protocolVersion ?? LATEST_PROTOCOL_VERSION,
    });

    // Check the MCP tool-error flag before the empty-text shortcut: an error
    // result can carry structuredContent and no text (see mcp-client
    // extractText), and returning [] here would report "No search results
    // found" for a failed search.
    if (result?.isError) {
      throw new Error(result.text || "TinyFish search failed");
    }

    // Structured-only responses carry empty text; TinyFish results live in
    // text as JSON, so empty text means no results.
    return result?.text ? parseTinyFishResults(result.text) : [];
  },
};
