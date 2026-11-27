import { VERSION } from "@earendil-works/pi-coding-agent";
import { mcpCall } from "../mcp-client";
import type {
  ProviderCallContext,
  WebSearchInput,
  WebSearchProvider,
  WebSearchResult,
} from "./types";

const FIRECRAWL_ENDPOINT = "https://mcp.firecrawl.dev/v2/mcp";

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
      throw new Error(result.text || "Firecrawl search failed");
    }
    // Firecrawl puts its hit JSON in MCP text, not structuredContent.
    return result?.text ? parseFirecrawlResults(result.text) : [];
  },
};
