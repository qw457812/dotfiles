export type ProviderID = "exa" | "parallel" | "firecrawl" | "tavily" | "tinyfish";

export interface WebSearchResult {
  url: string;
  title?: string;
  content?: string;
  /** Publication time in milliseconds since the Unix epoch. */
  published?: number;
}

// Preserve status and Retry-After for the selection layer's cooldown logic.
export class HttpCallError extends Error {
  override name = "HttpCallError";
  readonly status: number;
  readonly retryAfter: string | undefined;

  constructor(message: string, status: number, retryAfter?: string) {
    super(message);
    this.status = status;
    this.retryAfter = retryAfter;
  }
}

// Use typed identity so a server-supplied message cannot bypass error wrapping.
export class RequestCancelledError extends Error {
  override name = "RequestCancelledError";
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

export const PROVIDER_IDS: readonly ProviderID[] = [
  "exa",
  "parallel",
  "firecrawl",
  "tavily",
  "tinyfish",
];
