// Mirrors OpenCode's websearch; see README.md for the upstream pin and differences.

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
import { type Static, Type } from "typebox";
import { Value } from "typebox/value";

import { exaProvider } from "./providers/exa";
import { firecrawlProvider } from "./providers/firecrawl";
import { parallelProvider } from "./providers/parallel";
import { tavilyProvider } from "./providers/tavily";
import { tinyfishProvider } from "./providers/tinyfish";
import {
  HttpCallError,
  PROVIDER_IDS,
  RequestCancelledError,
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

type SavedFullOutput = { path: string } | { error: string };

async function saveFullOutput(prefix: string, text: string): Promise<SavedFullOutput> {
  let dir: string | undefined;
  try {
    dir = await mkdtemp(join(tmpdir(), prefix));
    const path = join(dir, "output.txt");
    await writeFile(path, text, "utf8");
    return { path };
  } catch (err) {
    if (dir) await rm(dir, { recursive: true, force: true }).catch(() => {});
    return { error: err instanceof Error ? err.message : String(err) };
  }
}

const WebSearchParamsSchema = Type.Object({
  query: Type.String({
    description: "Websearch query",
  }),
});

const WebSearchOutputSchema = Type.Array(
  Type.Object({
    url: Type.String(),
    title: Type.Optional(Type.String()),
    published: Type.Optional(
      Type.Number({ description: "Publication time in milliseconds since the Unix epoch" }),
    ),
    content: Type.Optional(Type.String()),
  }),
);

class InvalidWebSearchOutputError extends Error {
  override name = "InvalidWebSearchOutputError";
}

// OpenCode's description assumes an integration picker; this mirror uses environment variables.
function buildDescription(): string {
  const year = new Date().getFullYear();
  return `Search the web. Use this for current information beyond knowledge cutoff.

The current year is ${year}. Use this year when searching for recent information or current events.`;
}

const NO_RESULTS = "No search results found. Please try a different query.";

function formatResult(result: WebSearchResult): string {
  const title = result.title ?? result.url;
  const published =
    result.published !== undefined && Number.isFinite(result.published)
      ? `\nPublished: ${new Date(result.published).toISOString()}`
      : "";
  return `## [${title}](${result.url})${published}${result.content ? `\n\n${result.content}` : ""}`;
}

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

export default function (pi: ExtensionAPI) {
  const service = createWebSearchService([
    exaProvider,
    parallelProvider,
    firecrawlProvider,
    tavilyProvider,
    tinyfishProvider,
  ]);

  // Restore affinity from Pi's session log so resuming does not pick a new provider.
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

  pi.on("session_shutdown", (_event, ctx) => {
    service.forgetSession(ctx.sessionManager.getSessionId() ?? "");
  });

  pi.registerTool({
    name: "websearch",
    label: "Web Search",
    get description() {
      return buildDescription();
    },

    parameters: WebSearchParamsSchema,
    outputSchema: WebSearchOutputSchema,

    async execute(
      _toolCallId,
      params,
      signal,
      onUpdate,
      ctx,
    ): Promise<{
      content: Array<{ type: "text"; text: string }>;
      details: WebsearchDetails;
      structuredContent: Static<typeof WebSearchOutputSchema>;
    }> {
      const sessionID = ctx.sessionManager.getSessionId() ?? "default";

      const progressDetails: WebsearchDetails = { provider: "exa", attempts: 1 };
      const onProvider = (provider: ProviderID, attempt: number) => {
        progressDetails.provider = provider;
        progressDetails.attempts = attempt;
        onUpdate?.({
          content: [{ type: "text" as const, text: `Searching via ${providerLabel(provider)}...` }],
          details: { ...progressDetails },
        });
      };

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
        // Use typed identity: a remote error message can contain arbitrary text.
        if (err instanceof RequestCancelledError) throw err;
        throw wrapWebsearchError(err, params.query);
      }

      const structuredContent = queryResult.results.map(({ url, title, published, content }) => ({
        url,
        ...(title === undefined ? {} : { title }),
        ...(published === undefined ? {} : { published }),
        ...(content === undefined ? {} : { content }),
      }));
      if (!Value.Check(WebSearchOutputSchema, structuredContent)) {
        throw new InvalidWebSearchOutputError(
          `Invalid search results from ${queryResult.provider}`,
        );
      }

      // The Markdown preview is bounded; scripts get the original hits for filtering.
      const rawResult = structuredContent.length
        ? structuredContent.map(formatResult).join("\n\n")
        : NO_RESULTS;
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
        details.truncation = truncation;
        const saved = await saveFullOutput("pi-websearch-", rawResult);
        if ("path" in saved) {
          details.fullOutputPath = saved.path;
        } else {
          details.fullOutputError = saved.error;
        }

        const fullOutput =
          "path" in saved
            ? `Full output: ${saved.path}`
            : `Could not save the full output: ${saved.error}`;
        const startLine = 1;
        const endLine = truncation.outputLines;
        if (truncation.truncatedBy === "lines") {
          resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines}. ${fullOutput}]`;
        } else {
          resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines} (${formatSize(DEFAULT_MAX_BYTES)} limit). ${fullOutput}]`;
        }
      }

      return {
        content: [{ type: "text", text: resultText }],
        details,
        structuredContent,
      };
    },

    renderCall(args, theme, context) {
      // Before execution, only a forced provider is known.
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
        context,
      );
      component.invalidate();
      return component;
    },
  });
}
