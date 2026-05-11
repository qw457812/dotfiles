/**
 * Custom TUI rendering for the webfetch tool.
 * Mirrors pi's built-in bash/read/grep tool rendering patterns
 * and the websearch extension's rendering approach:
 * - Uses context.lastComponent for component reuse (no GC churn)
 * - Uses context.state for timing across call/result renders
 * - Uses theme.fg("toolOutput") for content
 * - Shows preview lines in collapsed view (like read/grep)
 * - Uses context.isError for error styling
 */

import {
  DEFAULT_MAX_BYTES,
  formatSize,
  keyHint,
  type TruncationResult,
} from "@earendil-works/pi-coding-agent";
import { Container, Text, truncateToWidth } from "@earendil-works/pi-tui";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface WebfetchDetails {
  url: string;
  format: "markdown" | "text" | "html";
  contentType?: string;
  isImage?: boolean;
  mime?: string;
  truncation?: TruncationResult;
  fullOutputPath?: string;
}

/** Shared renderer state for a webfetch tool row. */
export interface WebfetchRenderState {
  startedAt?: number;
  endedAt?: number;
  interval?: ReturnType<typeof setInterval>;
}

// ---------------------------------------------------------------------------
// Duration formatting
// ---------------------------------------------------------------------------

function formatDuration(ms: number): string {
  return `${(ms / 1000).toFixed(1)}s`;
}

// ---------------------------------------------------------------------------
// Call rendering
// ---------------------------------------------------------------------------

function truncateUrl(url: string, maxLen: number): string {
  if (url.length <= maxLen) return url;
  return url.slice(0, maxLen - 1) + "…";
}

export function formatWebfetchCall(
  args: { url?: string; format?: string } | undefined,
  theme: any,
): string {
  const invalidArg = theme.fg("error", "[invalid arg]");
  let text = theme.fg("toolTitle", theme.bold("webfetch "));
  if (args?.url) {
    text += theme.fg("accent", truncateUrl(args.url, 80));
  } else {
    text += invalidArg;
  }
  if (args?.format && args.format !== "markdown") {
    text += theme.fg("dim", ` [${args.format}]`);
  }
  return text;
}

// ---------------------------------------------------------------------------
// Result rendering
// ---------------------------------------------------------------------------

/** Collapsed preview: how many visual lines to show (mirrors bash's 5) */
const PREVIEW_LINES = 5;

// ---------------------------------------------------------------------------
// Container-based result rendering
// ---------------------------------------------------------------------------

/** Custom Container for webfetch result rendering with width-aware caching. */
export class WebfetchResultRenderComponent extends Container {
  state = {
    cachedWidth: undefined as number | undefined,
    cachedLines: undefined as string[] | undefined,
    cachedSkipped: undefined as number | undefined,
  };
}

/**
 * Rebuild the result component's children.
 *
 * Mirrors websearch's rebuildWebsearchResultRenderComponent:
 * - Status line as a Text child
 * - Content as a width-aware collapsed component or full expanded Text
 * - Truncation warning and duration as Text children
 */
export function rebuildWebfetchResultRenderComponent(
  component: WebfetchResultRenderComponent,
  result: { details?: WebfetchDetails; content: Array<{ type: string; text?: string }> },
  options: { expanded: boolean; isPartial: boolean },
  theme: any,
  state: WebfetchRenderState,
  isError: boolean,
): void {
  const cState = component.state;
  component.clear();

  const details = result.details;

  if (options.isPartial) {
    let text = theme.fg("warning", "Fetching...");
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

  // --- Image result ---
  if (details.isImage) {
    let statusText = theme.fg("success", "✓ Fetched image");
    if (details.mime) {
      statusText += theme.fg("muted", ` (${details.mime})`);
    }
    if (state.startedAt !== undefined) {
      const endTime = state.endedAt ?? Date.now();
      statusText += theme.fg("muted", ` Took ${formatDuration(endTime - state.startedAt)}`);
    }
    component.addChild(new Text(statusText, 0, 0));
    return;
  }

  // --- Error result ---
  if (isError) {
    let text = theme.fg("error", "✗ Fetch failed");
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

  // --- Text result ---
  let statusText = theme.fg("success", "✓ Fetched");
  if (details.contentType) {
    statusText += theme.fg("muted", ` (${details.contentType.split(";")[0]?.trim()})`);
  }
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
      component.addChild(new Text(`\n${styledOutput}`, 0, 0));
    } else {
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

  // --- Truncation warning ---
  const truncation = details.truncation;
  const fullOutputPath = details.fullOutputPath;
  if (truncation?.truncated || fullOutputPath) {
    const warnings: string[] = [];
    if (fullOutputPath) {
      warnings.push(`Full output: ${fullOutputPath}`);
    }
    if (truncation?.truncated) {
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
