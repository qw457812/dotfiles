/**
 * Tavily search provider — calls the Tavily REST search endpoint.
 *
 * Endpoint: POST https://api.tavily.com/search
 * Auth: Bearer token via TAVILY_API_KEY env var; without a key the request
 * sends X-Tavily-Access-Mode: keyless (mirrors OpenCode v2 — the keyless
 * tier is flaky, see README).
 * Tool: plain REST JSON (not MCP).
 *
 * Mirrors OpenCode v2's packages/core/src/plugin/websearch/tavily.ts:
 * body {query, search_depth: "basic", chunks_per_source: 3, max_results: 8}.
 */

import { VERSION } from "@earendil-works/pi-coding-agent";
import {
  HttpCallError,
  RequestCancelledError,
  type ProviderCallContext,
  type WebSearchInput,
  type WebSearchProvider,
  type WebSearchResult,
} from "./types";

const TAVILY_ENDPOINT = "https://api.tavily.com/search";

const REQUEST_TIMEOUT_MS = 25_000;

const PI_VERSION = `pi/${VERSION}`;

interface TavilySearchResponse {
  results: Array<{
    title?: string;
    url: string;
    content?: string;
  }>;
}

export const tavilyProvider: WebSearchProvider = {
  id: "tavily",
  label: "Tavily",
  async execute(input: WebSearchInput, ctx: ProviderCallContext): Promise<WebSearchResult[]> {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      Accept: "application/json",
      "User-Agent": PI_VERSION,
    };
    const apiKey = process.env.TAVILY_API_KEY;
    if (apiKey) {
      headers["Authorization"] = `Bearer ${apiKey}`;
    } else {
      headers["X-Tavily-Access-Mode"] = "keyless";
    }

    // Timeout + external signal linking (same pattern as mcp-client).
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    if (ctx.signal?.aborted) controller.abort();
    const onExternalAbort = () => controller.abort();
    ctx.signal?.addEventListener("abort", onExternalAbort, { once: true });

    try {
      const response = await fetch(TAVILY_ENDPOINT, {
        method: "POST",
        headers,
        body: JSON.stringify({
          query: input.query,
          search_depth: "basic",
          chunks_per_source: 3,
          max_results: 8,
        }),
        signal: controller.signal,
      });
      if (!response.ok) {
        const body = await response.text();
        console.error(`[tavily] HTTP ${response.status}: ${body.slice(0, 500)}`);
        throw new HttpCallError(
          `Tavily request failed: HTTP ${response.status} ${response.statusText}`,
          response.status,
          response.headers.get("retry-after") ?? undefined,
        );
      }
      const responseJson = (await response.json()) as Partial<TavilySearchResponse>;
      if (!Array.isArray(responseJson.results)) {
        throw new Error("Tavily response missing results");
      }
      return responseJson.results.map((item) => ({
        url: item.url,
        ...(item.title ? { title: item.title } : {}),
        ...(item.content ? { content: item.content } : {}),
      }));
    } catch (err: any) {
      if (err.name === "AbortError") {
        if (ctx.signal?.aborted) {
          throw new RequestCancelledError("Tavily request was cancelled");
        }
        throw new Error(`Tavily request timed out after ${REQUEST_TIMEOUT_MS}ms`);
      }
      throw err;
    } finally {
      clearTimeout(timeoutId);
      ctx.signal?.removeEventListener("abort", onExternalAbort);
    }
  },
};
