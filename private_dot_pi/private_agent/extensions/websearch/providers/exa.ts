// Exa returns text hit blocks with labeled fields rather than structured hits.

import { mcpCall } from "../mcp-client";
import type {
  ProviderCallContext,
  WebSearchInput,
  WebSearchProvider,
  WebSearchResult,
} from "./types";

const EXA_ENDPOINT = "https://mcp.exa.ai/mcp";

const NUM_RESULTS = 8;

function getExaUrl(): string {
  const apiKey = process.env.EXA_API_KEY;
  if (apiKey) {
    return `${EXA_ENDPOINT}?exaApiKey=${encodeURIComponent(apiKey)}`;
  }
  return EXA_ENDPOINT;
}

export function parseExaResults(text: string): WebSearchResult[] {
  return text.split(/\n\n---\n\n/).flatMap((block) => {
    const url = block.match(/^URL:\s*(.+)$/m)?.[1]?.trim();
    if (!url) return [];
    const title = block.match(/^Title:\s*(.+)$/m)?.[1]?.trim();
    const publishedText = block.match(/^Published:\s*(.+)$/m)?.[1]?.trim();
    const published =
      publishedText && publishedText !== "N/A" ? Date.parse(publishedText) : undefined;
    const content = block.match(/^(?:Highlights|Text):\s*\n?([\s\S]*)$/m)?.[1]?.trim();
    return [
      {
        url,
        ...(title && title !== "N/A" ? { title } : {}),
        ...(content ? { content } : {}),
        ...(published !== undefined && Number.isFinite(published) ? { published } : {}),
      },
    ];
  });
}

export const exaProvider: WebSearchProvider = {
  id: "exa",
  label: "Exa",
  async execute(input: WebSearchInput, ctx: ProviderCallContext): Promise<WebSearchResult[]> {
    const result = await mcpCall({
      url: getExaUrl(),
      tool: "web_search_exa",
      args: { query: input.query, numResults: NUM_RESULTS },
      timeout: 25_000,
      signal: ctx.signal,
    });
    if (result?.isError) {
      throw new Error(result.text || "Exa search failed");
    }
    return result ? parseExaResults(result.text) : [];
  },
};
