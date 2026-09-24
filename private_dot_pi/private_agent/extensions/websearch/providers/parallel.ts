/**
 * Parallel search provider — calls the remote Parallel MCP endpoint.
 *
 * Endpoint: https://search.parallel.ai/mcp
 * Auth: Bearer token via PARALLEL_API_KEY env var (optional).
 * Tool name: web_search
 *
 * Mirrors OpenCode v2's packages/core/src/plugin/websearch/parallel.ts:
 * - Sends only {objective, search_queries} (v1 also sent session_id/model_name)
 * - Parses structuredContent.results instead of passing text through verbatim
 * - User-Agent identifies pi (v2 uses opencode's app useragent)
 */

import { VERSION } from "@earendil-works/pi-coding-agent";
import { mcpCall, type McpCallResult } from "../mcp-client";
import type {
  ProviderCallContext,
  WebSearchInput,
  WebSearchProvider,
  WebSearchResult,
} from "./types";

const PARALLEL_ENDPOINT = "https://search.parallel.ai/mcp";

const PI_VERSION = `pi/${VERSION}`;

interface ParallelSearchResponse {
  results: Array<{
    url: string;
    title?: string;
    /** Publication date string, parsed with Date.parse. */
    publish_date?: string;
    /** Excerpts joined into the content field with blank lines. */
    excerpts: string[];
  }>;
}

function getParallelHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    "User-Agent": PI_VERSION,
  };
  const apiKey = process.env.PARALLEL_API_KEY;
  if (apiKey) {
    headers["Authorization"] = `Bearer ${apiKey}`;
  }
  return headers;
}

function parseParallelResults(mcpResult: McpCallResult): WebSearchResult[] {
  if (mcpResult.isError) {
    throw new Error(mcpResult.text);
  }
  const structured = mcpResult.structuredContent as Partial<ParallelSearchResponse> | undefined;
  if (!structured?.results || !Array.isArray(structured.results)) {
    throw new Error("Parallel response missing structuredContent.results");
  }
  return structured.results.map((item) => {
    const published = item.publish_date ? Date.parse(item.publish_date) : undefined;
    return {
      url: item.url,
      ...(item.title ? { title: item.title } : {}),
      ...(item.excerpts.length ? { content: item.excerpts.join("\n\n") } : {}),
      ...(published !== undefined && Number.isFinite(published) ? { published } : {}),
    };
  });
}

export const parallelProvider: WebSearchProvider = {
  id: "parallel",
  label: "Parallel",
  async execute(input: WebSearchInput, ctx: ProviderCallContext): Promise<WebSearchResult[]> {
    const result = await mcpCall({
      url: PARALLEL_ENDPOINT,
      tool: "web_search",
      args: {
        objective: input.query,
        search_queries: [input.query],
      },
      timeout: 25_000,
      headers: getParallelHeaders(),
      signal: ctx.signal,
    });
    if (!result) return [];
    return parseParallelResults(result);
  },
};
