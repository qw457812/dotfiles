/**
 * Firecrawl search provider — calls the remote Firecrawl MCP endpoint.
 *
 * Endpoint: https://mcp.firecrawl.dev/v2/mcp
 * Auth: Bearer token via FIRECRAWL_API_KEY env var (optional; the hosted MCP
 * endpoint works without a key at a lower rate).
 * Tool name: firecrawl_search
 *
 * Mirrors OpenCode v2's packages/core/src/plugin/websearch/firecrawl.ts:
 * MCP text content parsed as JSON ({success, data: {web: [{url, title, description}]}}).
 */

import { VERSION } from "@earendil-works/pi-coding-agent";
import { mcpCall } from "../mcp-client";
import type {
  ProviderCallContext,
  WebSearchInput,
  WebSearchProvider,
  WebSearchResult,
} from "./types";

const FIRECRAWL_ENDPOINT = "https://mcp.firecrawl.dev/v2/mcp";

/** OpenCode v2 hardcodes limit: 8 (the tool no longer exposes result counts). */
const RESULT_LIMIT = 8;

const PI_VERSION = `pi/${VERSION}`;

interface FirecrawlSearchResponse {
  success: boolean;
  data: {
    web: Array<{
      url: string;
      title?: string | null;
      description?: string | null;
    }>;
  };
}

function parseFirecrawlResults(text: string): WebSearchResult[] {
  const response = JSON.parse(text) as FirecrawlSearchResponse;
  if (!response.success || !Array.isArray(response.data?.web)) {
    throw new Error("Firecrawl response missing data.web");
  }
  return response.data.web.map((item) => ({
    url: item.url,
    ...(item.title ? { title: item.title } : {}),
    ...(item.description ? { content: item.description } : {}),
  }));
}

export const firecrawlProvider: WebSearchProvider = {
  id: "firecrawl",
  label: "Firecrawl",
  async execute(input: WebSearchInput, ctx: ProviderCallContext): Promise<WebSearchResult[]> {
    const headers: Record<string, string> = {
      "User-Agent": PI_VERSION,
    };
    const apiKey = process.env.FIRECRAWL_API_KEY;
    if (apiKey) {
      headers["Authorization"] = `Bearer ${apiKey}`;
    }
    const result = await mcpCall({
      url: FIRECRAWL_ENDPOINT,
      tool: "firecrawl_search",
      args: { query: input.query, limit: RESULT_LIMIT },
      timeout: 25_000,
      headers,
      signal: ctx.signal,
    });
    if (result?.isError) {
      throw new Error(result.text);
    }
    // Structured-only MCP responses carry an empty text (see mcp-client
    // extractText); firecrawl results live in text as JSON, so empty text
    // means no results here.
    return result?.text ? parseFirecrawlResults(result.text) : [];
  },
};
