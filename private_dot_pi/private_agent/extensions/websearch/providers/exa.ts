/**
 * Exa search provider — calls the remote Exa MCP endpoint.
 *
 * Endpoint: https://mcp.exa.ai/mcp
 * If EXA_API_KEY is set, it is appended to the URL.
 * Exa works without an API key (free tier), but a key unlocks higher limits.
 * Tool name: web_search_exa
 */

import { mcpCall } from "../mcp-client";
import type { ProviderCallContext, WebSearchParams } from "./types";

const EXA_BASE_URL = "https://mcp.exa.ai/mcp";

function getExaUrl(): string {
  const apiKey = process.env.EXA_API_KEY;
  if (apiKey) {
    return `${EXA_BASE_URL}?exaApiKey=${encodeURIComponent(apiKey)}`;
  }
  return EXA_BASE_URL;
}

export function callExa(
  params: WebSearchParams,
  ctx: ProviderCallContext,
): Promise<string | undefined> {
  return mcpCall({
    url: getExaUrl(),
    tool: "web_search_exa",
    args: {
      query: params.query,
      type: params.type || "auto",
      numResults: params.numResults || 8,
      livecrawl: params.livecrawl || "fallback",
      ...(params.contextMaxCharacters != null
        ? { contextMaxCharacters: params.contextMaxCharacters }
        : {}),
    },
    timeout: 25_000,
    signal: ctx.signal,
  });
}
