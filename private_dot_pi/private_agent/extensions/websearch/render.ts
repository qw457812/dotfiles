/**
 * Custom TUI rendering for the websearch tool.
 * Mirrors pi's built-in bash/read/grep tool rendering patterns:
 * - Uses context.lastComponent for component reuse (no GC churn)
 * - Uses context.state for timing across call/result renders
 * - Uses theme.fg("toolOutput") for content (not "dim")
 * - Shows preview lines in collapsed view (like read/grep)
 * - Uses context.isError for error styling
 * - Distinguishes line vs byte truncation with formatSize
 */

import {
  DEFAULT_MAX_BYTES,
  formatSize,
  keyHint,
  type TruncationResult,
} from "@earendil-works/pi-coding-agent";
import { Container, Text, truncateToWidth } from "@earendil-works/pi-tui";
import type { WebSearchProvider } from "./providers/types";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface WebsearchDetails {
  provider: WebSearchProvider;
  truncation?: TruncationResult;
  fullOutputPath?: string;
}

/** Shared renderer state for a websearch tool row. */
export interface WebsearchRenderState {
  startedAt?: number;
  endedAt?: number;
  interval?: ReturnType<typeof setInterval>;
}

interface WebsearchCallArgs {
  query: string;
  numResults?: number;
  type?: string;
  livecrawl?: string;
}

// ---------------------------------------------------------------------------
// Provider labels
// ---------------------------------------------------------------------------

export function providerLabel(provider: WebSearchProvider): string {
  if (provider === "parallel") return "Parallel Web Search";
  if (provider === "exa") return "Exa Web Search";
  return "Web Search";
}

export function providerShortLabel(provider: WebSearchProvider): string {
  if (provider === "parallel") return "Parallel";
  if (provider === "exa") return "Exa";
  return "Web";
}

// ---------------------------------------------------------------------------
// Duration formatting (mirrors bash tool)
// ---------------------------------------------------------------------------

function formatDuration(ms: number): string {
  return `${(ms / 1000).toFixed(1)}s`;
}

// ---------------------------------------------------------------------------
// Call rendering
// ---------------------------------------------------------------------------

export function formatWebsearchCall(
  args: WebsearchCallArgs | undefined,
  provider: WebSearchProvider | undefined,
  theme: any,
): string {
  const invalidArg = theme.fg("error", "[invalid arg]");
  let text = theme.fg("toolTitle", theme.bold("websearch "));
  text += args?.query ? theme.fg("accent", `"${args.query}"`) : invalidArg;
  if (provider) {
    text += theme.fg("muted", ` [${providerShortLabel(provider)}]`);
  }
  // Show non-default parameters (mirrors read's offset/limit, grep's glob/limit)
  const extras: string[] = [];
  if (args?.numResults !== undefined && args.numResults !== 8) {
    extras.push(`${args.numResults} results`);
  }
  if (args?.type && args.type !== "auto") {
    extras.push(args.type);
  }
  if (args?.livecrawl && args.livecrawl !== "fallback") {
    extras.push(`livecrawl=${args.livecrawl}`);
  }
  if (extras.length > 0) {
    text += theme.fg("dim", ` (${extras.join(", ")})`);
  }
  return text;
}

// ---------------------------------------------------------------------------
// Result rendering
// ---------------------------------------------------------------------------

/** Collapsed preview: how many visual lines to show (mirrors bash's BASH_PREVIEW_LINES = 5) */
const PREVIEW_LINES = 5;

// ---------------------------------------------------------------------------
// Container-based result rendering (mirrors bash tool)
// ---------------------------------------------------------------------------

/** Custom Container for websearch result rendering with width-aware caching. */
export class WebsearchResultRenderComponent extends Container {
  state = {
    cachedWidth: undefined as number | undefined,
    cachedLines: undefined as string[] | undefined,
    cachedSkipped: undefined as number | undefined,
  };
}

/**
 * Rebuild the result component's children.
 *
 * Mirrors bash's rebuildBashResultRenderComponent:
 * - Status line as a Text child
 * - Content as a width-aware collapsed component or full expanded Text
 * - Truncation warning and duration as Text children
 */
export function rebuildWebsearchResultRenderComponent(
  component: WebsearchResultRenderComponent,
  result: { details?: WebsearchDetails; content: Array<{ type: string; text?: string }> },
  options: { expanded: boolean; isPartial: boolean },
  theme: any,
  state: WebsearchRenderState,
  isError: boolean,
): void {
  const cState = component.state;
  component.clear();

  const details = result.details;

  if (options.isPartial) {
    let text = theme.fg("warning", "Searching...");
    if (state.startedAt !== undefined) {
      const elapsed = Date.now() - state.startedAt;
      text += theme.fg("muted", ` (Elapsed ${formatDuration(elapsed)})`);
    }
    component.addChild(new Text(text, 0, 0));
    return;
  }

  if (!details) {
    if (isError) {
      component.addChild(new Text(theme.fg("error", "Failed"), 0, 0));
    } else {
      component.addChild(new Text(theme.fg("dim", "Done"), 0, 0));
    }
    return;
  }

  const label = providerShortLabel(details.provider);

  if (isError) {
    let text = theme.fg("error", `✗ ${label}`);
    const content = result.content[0];
    if (content?.type === "text" && content.text) {
      const firstLine = content.text.split("\n")[0];
      text += theme.fg("dim", ` ${firstLine}`);
    }
    if (state.startedAt !== undefined) {
      const endTime = state.endedAt ?? Date.now();
      text += theme.fg("muted", ` Took ${formatDuration(endTime - state.startedAt)}`);
    }
    component.addChild(new Text(text, 0, 0));
    return;
  }

  let statusText = theme.fg("success", `✓ ${label}`);
  if (details.truncation?.truncated) {
    statusText += theme.fg("warning", " (truncated)");
  }
  if (state.startedAt !== undefined) {
    const endTime = state.endedAt ?? Date.now();
    statusText += theme.fg("muted", ` Took ${formatDuration(endTime - state.startedAt)}`);
  }
  component.addChild(new Text(statusText, 0, 0));

  const content = result.content[0];
  if (content?.type === "text" && content.text) {
    const lines = content.text.split("\n");
    let end = lines.length;
    while (end > 0 && lines[end - 1] === "") end--;
    const trimmedLines = lines.slice(0, end);

    const styledOutput = trimmedLines.map((line) => theme.fg("toolOutput", line)).join("\n");

    if (options.expanded) {
      // Show all lines (mirrors bash/read expanded view)
      component.addChild(new Text(`\n${styledOutput}`, 0, 0));
    } else {
      // Width-aware collapsed preview using truncateToVisualLines (same as bash tool).
      // NOTE: Unlike bash (which uses tail truncation for command output),
      // websearch uses truncateToVisualLines but discards the tail-truncated result
      // and instead takes the head — this is intentional since search results are
      // most relevant at the top.
      component.addChild({
        render: (width: number) => {
          if (cState.cachedLines === undefined || cState.cachedWidth !== width) {
            const tempText = new Text(`\n${styledOutput}`, 0, 0);
            const allVisualLines = tempText.render(width);
            if (allVisualLines.length <= PREVIEW_LINES + 1) {
              cState.cachedLines = allVisualLines;
              cState.cachedSkipped = 0;
            } else {
              cState.cachedLines = allVisualLines.slice(0, PREVIEW_LINES + 1);
              cState.cachedSkipped = allVisualLines.length - (PREVIEW_LINES + 1);
            }
            cState.cachedWidth = width;
          }
          if (cState.cachedSkipped && cState.cachedSkipped > 0) {
            const hint =
              theme.fg("muted", `... (${cState.cachedSkipped} more lines,`) +
              ` ${keyHint("app.tools.expand", "to expand")})`;
            return [...(cState.cachedLines ?? []), truncateToWidth(hint, width, "...")];
          }
          return cState.cachedLines ?? [];
        },
        invalidate: () => {
          cState.cachedWidth = undefined;
          cState.cachedLines = undefined;
          cState.cachedSkipped = undefined;
        },
      });
    }
  }

  // Truncation warning (mirrors bash tool's bracket format with formatSize)
  const truncation = details.truncation;
  const fullOutputPath = details.fullOutputPath;
  if (truncation?.truncated || fullOutputPath) {
    const warnings: string[] = [];
    if (fullOutputPath) {
      warnings.push(`Full output: ${fullOutputPath}`);
    }
    if (truncation?.truncated) {
      // Distinguish truncation cause (mirrors bash tool)
      if (truncation.truncatedBy === "lines") {
        warnings.push(
          `Truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines`,
        );
      } else {
        warnings.push(
          `Truncated: ${truncation.outputLines} lines shown (${formatSize(truncation.maxBytes ?? DEFAULT_MAX_BYTES)} limit)`,
        );
      }
    }
    component.addChild(new Text(`\n${theme.fg("warning", `[${warnings.join(". ")}]`)}`, 0, 0));
  }
}
