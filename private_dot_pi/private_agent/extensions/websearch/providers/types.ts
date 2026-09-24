/**
 * Shared types for websearch providers.
 *
 * Mirrors OpenCode v2's WebSearch schema (packages/schema/src/websearch.ts):
 * every provider parses its response into structured WebSearchResult objects.
 */

export type ProviderID = "exa" | "parallel" | "firecrawl" | "tavily";

export interface WebSearchResult {
  url: string;
  title?: string;
  content?: string;
  /** Publication time in milliseconds since the Unix epoch. */
  published?: number;
}

/**
 * HTTP layer error carrying the response status.
 *
 * The selection layer checks `status === 429` (plus Retry-After) to drive
 * cooldown and failover, mirroring OpenCode v2's HttpClientError handling.
 */
export class HttpCallError extends Error {
  override name = "HttpCallError";
  readonly status: number;
  /** Raw Retry-After header value: seconds or HTTP-date. */
  readonly retryAfter: string | undefined;

  constructor(message: string, status: number, retryAfter?: string) {
    super(message);
    this.status = status;
    this.retryAfter = retryAfter;
  }
}

export interface WebSearchInput {
  query: string;
}

export interface ProviderCallContext {
  signal?: AbortSignal;
}

export interface WebSearchProvider {
  id: ProviderID;
  label: string;
  execute(input: WebSearchInput, ctx: ProviderCallContext): Promise<WebSearchResult[]>;
}

/** All provider ids, in registration order. Also validates env overrides. */
export const PROVIDER_IDS: readonly ProviderID[] = ["exa", "parallel", "firecrawl", "tavily"];
