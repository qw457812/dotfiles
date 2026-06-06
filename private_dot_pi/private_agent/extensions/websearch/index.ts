/**
 * Pi WebSearch Extension
 *
 * Adds a `websearch` tool that searches the internet using Exa or Parallel
 * via their remote MCP-over-HTTP endpoints.
 *
 * Architecture mirrors OpenCode's websearch implementation:
 * - Dual provider routing (Exa / Parallel) with deterministic A/B split
 * - MCP over HTTP (remote endpoints, no local processes)
 * - FNV-1a hash for session-based routing (same as OpenCode)
 * - Both Exa and Parallel have free tiers that work without API keys
 * - Output truncation with temp file fallback
 *
 * Configuration (environment variables):
 *   EXA_API_KEY          — Exa API key (optional; unlocks higher rate limits)
 *   PARALLEL_API_KEY     — Parallel API key (optional; unlocks higher rate limits)
 *   PI_WEBSEARCH_PROVIDER — Force "exa" or "parallel" (optional)
 *
 * Provider selection (mirrors OpenCode exactly):
 *   1. PI_WEBSEARCH_PROVIDER override → forced provider
 *   2. FNV-1a hash of session ID → deterministic A/B routing (default)
 *   API keys are only for authentication, they do NOT affect provider selection.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  truncateHead,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { Type } from "typebox";

import { callExa } from "./providers/exa";
import { callParallel } from "./providers/parallel";
import type { ProviderCallContext, WebSearchParams, WebSearchProvider } from "./providers/types";
import type { McpCallResult } from "./mcp-client";
import {
  formatWebsearchCall,
  providerLabel,
  rebuildWebsearchResultRenderComponent,
  WebsearchResultRenderComponent,
  type WebsearchDetails,
  type WebsearchRenderState,
} from "./render";

// ---------------------------------------------------------------------------
// FNV-1a hash (same as OpenCode's checksum in core/util/encode.ts)
// ---------------------------------------------------------------------------

function fnv1aChecksum(content: string): string | undefined {
  if (!content) return undefined;
  let hash = 0x811c9dc5;
  for (let i = 0; i < content.length; i++) {
    hash ^= content.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(36);
}

// ---------------------------------------------------------------------------
// Provider selection (mirrors OpenCode's selectWebSearchProvider)
// ---------------------------------------------------------------------------

function selectProvider(sessionID: string): WebSearchProvider {
  const override = process.env.PI_WEBSEARCH_PROVIDER;
  if (override === "exa" || override === "parallel") return override;

  const checksum = fnv1aChecksum(sessionID) ?? "0";
  return Number.parseInt(checksum, 36) % 2 === 0 ? "exa" : "parallel";
}

// ---------------------------------------------------------------------------
// Tool schema (mirrors OpenCode's Parameters)
// ---------------------------------------------------------------------------

const WebSearchParamsSchema = Type.Object({
  query: Type.String({
    description: "Websearch query",
  }),
  numResults: Type.Optional(
    Type.Integer({
      description: "Number of search results to return (default: 8)",
      minimum: 1,
    }),
  ),
});

// ---------------------------------------------------------------------------
// Description builder (lazy year evaluation, adapted from OpenCode's websearch.txt)
// ---------------------------------------------------------------------------

// TODO: shorten tool description, add promptSnippet/promptGuidelines if needed
// - https://www.npmjs.com/package/@ollama/pi-web-search?activeTab=code
// - https://github.com/juicesharp/rpiv-mono/blob/b4a2b7543b95d8d1e5a4d2e842bd9a09b555e225/packages/rpiv-web-tools/web-tools.ts
function buildDescription(): string {
  const year = new Date().getFullYear();
  return `- Search the web
- Provides up-to-date information for current events and recent data
- Supports configurable result counts and returns the content from the most relevant websites
- Use this tool for accessing information beyond knowledge cutoff
- Searches are performed automatically within a single API call

The current year is ${year}. You MUST use this year when searching for recent information or current events
- Example: If the current year is ${year} and the user asks for "latest AI news", search for "AI news ${year}", NOT "AI news ${year - 1}"`;
}

// ---------------------------------------------------------------------------
// Temp file tracking for cleanup on session shutdown
// ---------------------------------------------------------------------------

const tempFiles: string[] = [];

async function cleanupTempFiles(): Promise<void> {
  // Snapshot paths before clearing so failures can be re-queued
  const dirs = [...tempFiles];
  tempFiles.length = 0;
  const failed: string[] = [];
  for (const dir of dirs) {
    try {
      await rm(dir, { recursive: true, force: true });
    } catch (err: any) {
      // Re-queue for next cleanup attempt; log for diagnostics
      console.warn(`[websearch] Failed to clean up temp dir ${dir}:`, err.message || err);
      failed.push(dir);
    }
  }
  if (failed.length > 0) {
    tempFiles.push(...failed);
  }
}

// ---------------------------------------------------------------------------
// Cached session ID for renderCall (lacks ExtensionContext).
// Set on session_start, cleared on session_shutdown; renderResult
// always shows the accurate provider from execute's details.
// ---------------------------------------------------------------------------

let cachedSessionID: string | undefined;

// ---------------------------------------------------------------------------
// Extension entry
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    cachedSessionID = ctx.sessionManager.getSessionId();
  });

  pi.on("session_shutdown", async () => {
    cachedSessionID = undefined;
    await cleanupTempFiles();
  });

  pi.registerTool({
    name: "websearch",
    label: "Web Search",
    get description() {
      return buildDescription();
    },

    parameters: WebSearchParamsSchema,

    async execute(
      _toolCallId,
      params,
      signal,
      onUpdate,
      ctx,
    ): Promise<{
      content: Array<{ type: "text"; text: string }>;
      details: WebsearchDetails;
    }> {
      const sessionID = ctx.sessionManager.getSessionId() ?? "default";

      // Model name for Parallel analytics (mirrors OpenCode's webSearchModelName)
      // OpenCode: (model.api.id ?? model.id)?.slice(0, 100)
      // Pi: model.api is a string type ("anthropic-messages"), not an object with .id,
      // so use model.id directly, truncated to 100 chars.
      const model = ctx.model;
      const modelName = model?.id ? model.id.slice(0, 100) : undefined;

      const provider = selectProvider(sessionID);
      const label = providerLabel(provider);

      onUpdate?.({
        content: [{ type: "text" as const, text: `Searching via ${label}...` }],
        details: { provider },
      });

      const callCtx: ProviderCallContext = {
        sessionID,
        modelName,
        signal,
      };

      const searchParams: WebSearchParams = {
        query: params.query,
        numResults: params.numResults,
      };

      let mcpResult: McpCallResult | undefined;
      try {
        if (provider === "exa") {
          mcpResult = await callExa(searchParams, callCtx);
        } else {
          mcpResult = await callParallel(searchParams, callCtx);
        }
      } catch (err: any) {
        throw new Error(`WebSearch (${label}) failed: ${err.message}`, { cause: err });
      }

      // MCP spec: isError results are returned (not thrown) so the LLM can
      // see the error content and self-correct. Prefix with a clear marker
      // so the LLM knows this is an error, not search results.
      let rawResult: string;
      if (!mcpResult) {
        rawResult = "No search results found. Please try a different query.";
      } else if (mcpResult.isError) {
        rawResult = `[Search provider returned an error]\n${mcpResult.text}`;
      } else {
        rawResult = mcpResult.text;
      }

      const truncation = truncateHead(rawResult, {
        maxLines: DEFAULT_MAX_LINES,
        maxBytes: DEFAULT_MAX_BYTES,
      });

      const details: WebsearchDetails = {
        provider,
        isError: mcpResult?.isError ?? false,
      };

      let resultText = truncation.content;

      if (truncation.truncated) {
        const tempDir = await mkdtemp(join(tmpdir(), "pi-websearch-"));
        const tempFile = join(tempDir, "output.txt");
        await writeFile(tempFile, rawResult, "utf8");

        tempFiles.push(tempDir);

        details.truncation = truncation;
        details.fullOutputPath = tempFile;

        const truncatedLines = truncation.totalLines - truncation.outputLines;

        // NOTE: The truncation message format here intentionally differs
        // from pi's built-in bash/read tools (which use `[Showing lines X-Y]`)
        // to match OpenCode's websearch truncation format exactly.
        // The TUI render layer (renderResult) uses the structured details
        // and aligns with bash/read's bracket format for display consistency.
        resultText += `\n\n...${truncatedLines} lines truncated...\n\nThe tool call succeeded but the output was truncated. Full output saved to: ${tempFile}\nUse bash with rg to search the full content or read with offset/limit to view specific sections.`;
      }

      return {
        content: [{ type: "text" as const, text: resultText }],
        details,
      };
    },

    renderCall(args, theme, context) {
      const provider = cachedSessionID ? selectProvider(cachedSessionID) : undefined;

      const state = context.state as WebsearchRenderState;
      if (context.executionStarted && state.startedAt === undefined) {
        state.startedAt = Date.now();
        state.endedAt = undefined;
      }

      const text = (context.lastComponent as Text) ?? new Text("", 0, 0);
      text.setText(
        formatWebsearchCall(
          {
            query: args?.query,
            numResults: args?.numResults,
          },
          provider,
          theme,
        ),
      );
      return text;
    },

    renderResult(result, options, theme, context) {
      const state = context.state as WebsearchRenderState;

      if (state.startedAt !== undefined && options.isPartial && !state.interval) {
        state.interval = setInterval(() => context.invalidate(), 1000);
      }

      if (!options.isPartial) {
        state.endedAt ??= Date.now();
        if (state.interval) {
          clearInterval(state.interval);
          state.interval = undefined;
        }
      }

      const component =
        (context.lastComponent as WebsearchResultRenderComponent | undefined) ??
        new WebsearchResultRenderComponent();
      rebuildWebsearchResultRenderComponent(
        component,
        result as any,
        options,
        theme,
        state,
        context.isError,
      );
      component.invalidate();
      return component;
    },
  });
}
