/**
 * Exa search provider — calls the remote Exa MCP endpoint.
 *
 * Endpoint: https://mcp.exa.ai/mcp
 * If EXA_API_KEY is set, it is appended to the URL (mirrors OpenCode v2).
 * Exa works without an API key (free tier), but a key unlocks higher limits.
 * Tool name: web_search_exa
 *
 * Result parsing mirrors OpenCode v2's packages/core/src/plugin/websearch/exa.ts:
 * text blocks separated by `\n\n---\n\n`, fields matched with URL: / Title: /
 * Published: / Highlights|Text: lines. "N/A" values are dropped.
 */

import { mcpCall } from "../mcp-client";
import type {
  ProviderCallContext,
  WebSearchInput,
  WebSearchProvider,
  WebSearchResult,
} from "./types";

const EXA_ENDPOINT = "https://mcp.exa.ai/mcp";

/** OpenCode v2 hardcodes numResults: 8 (the tool no longer exposes it). */
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
      throw new Error(result.text);
    }
    return result ? parseExaResults(result.text) : [];
  },
};
