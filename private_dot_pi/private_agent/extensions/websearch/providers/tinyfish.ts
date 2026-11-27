// Keyed requests require an MCP session; keyless requests are stateless and do not get a session ID.

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

// Both handshake requests share one deadline.
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

// Surface protocol errors before checking for a missing session ID.
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

// The server acknowledges initialized with an empty 204; use the raw request path.
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

    // MCP errors can carry structuredContent without text; don't treat those as no hits.
    if (result?.isError) {
      throw new Error(result.text || "TinyFish search failed");
    }

    // TinyFish puts its hit JSON in MCP text, not structuredContent.
    return result?.text ? parseTinyFishResults(result.text) : [];
  },
};
