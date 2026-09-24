/**
 * Pi WebSearch Extension
 *
 * Adds a `websearch` tool that searches the internet via remote
 * MCP-over-HTTP / REST endpoints, mirroring OpenCode v2's websearch
 * architecture (packages/core/src/{websearch,plugin/websearch} at the
 * commit pinned in README.md):
 *
 * - Four providers: Exa, Parallel, Firecrawl, Tavily (v2's TinyFish is
 *   excluded — see README)
 * - Selection: PI_WEBSEARCH_PROVIDER forces a provider; default "random"
 *   routes per-session with sticky affinity, HTTP 429 cooldowns sized by
 *   Retry-After, and failover across providers
 * - Results are structured per provider and formatted as markdown the LLM
 *   consumes: ## [title](url) + Published + content
 * - Output truncation with temp file fallback (pi conventions)
 * - Session-scoped affinity persistence via appendEntry/CustomEntry, so
 *   `pi --resume` keeps the same provider
 *
 * Configuration (environment variables):
 *   PI_WEBSEARCH_PROVIDER — "exa" | "parallel" | "firecrawl" | "tavily" | "random" (default)
 *   EXA_API_KEY           — Exa API key (optional; unlocks higher rate limits)
 *   PARALLEL_API_KEY      — Parallel API key (optional)
 *   FIRECRAWL_API_KEY     — Firecrawl API key (optional)
 *   TAVILY_API_KEY        — Tavily API key (optional; the keyless tier is flaky)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  truncateHead,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { Type } from "typebox";

import { exaProvider } from "./providers/exa";
import { firecrawlProvider } from "./providers/firecrawl";
import { parallelProvider } from "./providers/parallel";
import { tavilyProvider } from "./providers/tavily";
import {
  HttpCallError,
  PROVIDER_IDS,
  type ProviderID,
  type WebSearchResult,
} from "./providers/types";
import {
  formatWebsearchCall,
  providerLabel,
  rebuildWebsearchResultRenderComponent,
  WebsearchResultRenderComponent,
  type WebsearchDetails,
  type WebsearchRenderState,
} from "./render";
import {
  createWebSearchService,
  forcedSelection,
  SELECTION_ENTRY_TYPE,
  type WebSearchQueryResult,
} from "./selection";

// ---------------------------------------------------------------------------
// Tool schema (mirrors OpenCode v2: query only, result count fixed at 8)
// ---------------------------------------------------------------------------

const WebSearchParamsSchema = Type.Object({
  query: Type.String({
    description: "Websearch query",
  }),
});

// ---------------------------------------------------------------------------
// Description builder (v2's two-line description with lazy year)
//
// Deviation: v2's first sentence is "Search the web using the user's selected
// search integration" — accurate there because OpenCode has consent-flow /
// KV-persisted provider selection and an integrations UI. This extension's
// selection is env-only (PI_WEBSEARCH_PROVIDER) with no user-visible picker,
// so the description stays truthful with a plain "Search the web".
// ---------------------------------------------------------------------------

function buildDescription(): string {
  const year = new Date().getFullYear();
  return `Search the web. Use this for current information beyond knowledge cutoff.

The current year is ${year}. Use this year when searching for recent information or current events.`;
}

// ---------------------------------------------------------------------------
// Result formatting (v2's tool content format)
// ---------------------------------------------------------------------------

const NO_RESULTS = "No search results found. Please try a different query.";

function formatResult(result: WebSearchResult): string {
  const title = result.title ?? result.url;
  const published =
    result.published !== undefined && Number.isFinite(result.published)
      ? `\nPublished: ${new Date(result.published).toISOString()}`
      : "";
  return `## [${title}](${result.url})${published}${result.content ? `\n\n${result.content}` : ""}`;
}

function formatResults(raw: WebSearchQueryResult): string {
  return raw.results.length ? raw.results.map(formatResult).join("\n\n") : NO_RESULTS;
}

// ---------------------------------------------------------------------------
// Error wrapping (v2's ToolFailure messages)
// ---------------------------------------------------------------------------

function wrapWebsearchError(err: unknown, query: string): Error {
  if (err instanceof HttpCallError) {
    if (err.status === 429) return new Error("Web search rate limited (HTTP 429)", { cause: err });
    if (err.status === 401) {
      return new Error("Web search authentication failed (HTTP 401)", { cause: err });
    }
    return new Error(`Web search request failed (HTTP ${err.status})`, {
      cause: err,
    });
  }
  return new Error(`Unable to search the web for ${query}`, {
    cause: err instanceof Error ? err : undefined,
  });
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
// Extension entry
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  const service = createWebSearchService([
    exaProvider,
    parallelProvider,
    firecrawlProvider,
    tavilyProvider,
  ]);

  // Restore this session's provider affinity from the last persisted
  // "websearch.selection" custom entry (pi --resume keeps the same provider).
  pi.on("session_start", (_event, ctx) => {
    const defaultSessionID = ctx.sessionManager.getSessionId();
    if (!defaultSessionID) return;
    const entries = ctx.sessionManager.getEntries();
    for (let i = entries.length - 1; i >= 0; i--) {
      const entry = entries[i] as {
        type?: string;
        customType?: string;
        data?: { provider?: string };
      };
      if (entry.type === "custom" && entry.customType === SELECTION_ENTRY_TYPE) {
        const provider = entry.data?.provider;
        if (provider && (PROVIDER_IDS as readonly string[]).includes(provider)) {
          service.restoreAffinity(defaultSessionID, provider as ProviderID);
        }
        break;
      }
    }
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    service.forgetSession(ctx.sessionManager.getSessionId() ?? "");
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

      // Stream progress: which provider, which attempt (visible on failover).
      const progressDetails: WebsearchDetails = { provider: "exa", attempts: 1 };
      const onProvider = (provider: ProviderID, attempt: number) => {
        progressDetails.provider = provider;
        progressDetails.attempts = attempt;
        onUpdate?.({
          content: [{ type: "text" as const, text: `Searching via ${providerLabel(provider)}...` }],
          details: { ...progressDetails },
        });
      };

      // Persist affinity changes as session entries (restore source on resume).
      const onAffinityChange = (provider: ProviderID) => {
        pi.appendEntry(SELECTION_ENTRY_TYPE, { provider });
      };

      let queryResult: WebSearchQueryResult;
      try {
        queryResult = await service.query(
          { query: params.query },
          {
            sessionID,
            signal,
            onProvider,
            onAffinityChange,
          },
        );
      } catch (err) {
        // User cancellation bypasses the error wrap (pi abort semantics, like
        // the webfetch mirror): providers surface aborts as "... was cancelled"
        // and that plain message must reach the caller unchanged.
        if (err instanceof Error && err.message.endsWith("was cancelled")) throw err;
        throw wrapWebsearchError(err, params.query);
      }

      const rawResult = formatResults(queryResult);

      const truncation = truncateHead(rawResult, {
        maxLines: DEFAULT_MAX_LINES,
        maxBytes: DEFAULT_MAX_BYTES,
      });

      const details: WebsearchDetails = {
        provider: queryResult.provider,
        attempts: queryResult.attempts,
      };

      let resultText = truncation.content;

      if (truncation.truncated) {
        const tempDir = await mkdtemp(join(tmpdir(), "pi-websearch-"));
        const tempFile = join(tempDir, "output.txt");
        await writeFile(tempFile, rawResult, "utf8");

        tempFiles.push(tempDir);

        details.truncation = truncation;
        details.fullOutputPath = tempFile;

        // pi convention (bash tool): bracket-format continuation notice.
        const startLine = 1;
        const endLine = truncation.outputLines;
        if (truncation.truncatedBy === "lines") {
          resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines}. Full output: ${tempFile}]`;
        } else {
          resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines} (${formatSize(DEFAULT_MAX_BYTES)} limit). Full output: ${tempFile}]`;
        }
      }

      return {
        content: [{ type: "text", text: resultText }],
        details,
      };
    },

    renderCall(args, theme, context) {
      // The provider is only known at execution time (random + cooldowns);
      // renderCall shows the query and, when the env forces a provider,
      // that fixed label.
      const state = context.state as WebsearchRenderState;
      if (context.executionStarted && state.startedAt === undefined) {
        state.startedAt = Date.now();
        state.endedAt = undefined;
      }

      const text = (context.lastComponent as Text) ?? new Text("", 0, 0);
      text.setText(formatWebsearchCall({ query: args?.query }, forcedSelection(), theme));
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
