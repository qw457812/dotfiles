/**
 * Parallel search provider — calls the remote Parallel MCP endpoint.
 *
 * Endpoint: https://search.parallel.ai/mcp
 * Auth: Bearer token via PARALLEL_API_KEY env var (optional).
 * Tool name: web_search
 *
 * Mirrors OpenCode: passes MCP content.text through verbatim to the LLM.
 * No JSON parse/reformat — avoids information loss and format inconsistency
 * between parseable and non-parseable responses.
 */

import { VERSION } from "@earendil-works/pi-coding-agent";
import { mcpCall, type McpCallResult } from "../mcp-client";
import type { ProviderCallContext, WebSearchParams } from "./types";

const PARALLEL_URL = "https://search.parallel.ai/mcp";

const PI_VERSION = `pi/${VERSION}`;

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

export function callParallel(
  params: WebSearchParams,
  ctx: ProviderCallContext,
): Promise<McpCallResult | undefined> {
  return mcpCall({
    url: PARALLEL_URL,
    tool: "web_search",
    args: {
      objective: params.query,
      search_queries: [params.query],
      ...(ctx.sessionID ? { session_id: ctx.sessionID } : {}),
      ...(ctx.modelName ? { model_name: ctx.modelName } : {}),
    },
    timeout: 25_000,
    headers: getParallelHeaders(),
    signal: ctx.signal,
  });
}
