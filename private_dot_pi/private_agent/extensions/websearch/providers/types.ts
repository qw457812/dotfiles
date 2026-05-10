/**
 * Shared types for websearch providers.
 */

export type WebSearchProvider = "exa" | "parallel";

export interface WebSearchParams {
  query: string;
  numResults?: number;
  livecrawl?: "fallback" | "preferred";
  type?: "auto" | "fast" | "deep";
  contextMaxCharacters?: number;
}

export interface ProviderCallContext {
  sessionID: string;
  modelName?: string;
  signal?: AbortSignal;
}
