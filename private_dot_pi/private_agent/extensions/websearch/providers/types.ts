/**
 * Shared types for websearch providers.
 */

export type WebSearchProvider = "exa" | "parallel";

export interface WebSearchParams {
  query: string;
  numResults?: number;
}

export interface ProviderCallContext {
  sessionID: string;
  modelName?: string;
  signal?: AbortSignal;
}
