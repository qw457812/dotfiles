import {
  DEFAULT_MAX_BYTES,
  formatSize,
  type KeybindingHints,
  type TruncationResult,
} from "@earendil-works/pi-coding-agent";
import { Container, Text, truncateToWidth } from "@earendil-works/pi-tui";
import type { ProviderID } from "./providers/types";

export interface WebsearchDetails {
  provider: ProviderID;
  /** Providers attempted (1 unless failover happened). */
  attempts?: number;
  truncation?: TruncationResult;
  fullOutputPath?: string;
  fullOutputError?: string;
}

export interface WebsearchRenderState {
  startedAt?: number;
  endedAt?: number;
  interval?: ReturnType<typeof setInterval>;
}

interface WebsearchCallArgs {
  query: string;
}

export function providerLabel(provider: ProviderID): string {
  if (provider === "parallel") return "Parallel";
  if (provider === "exa") return "Exa";
  if (provider === "tavily") return "Tavily";
  if (provider === "firecrawl") return "Firecrawl";
  if (provider === "tinyfish") return "TinyFish";
  return "Web";
}

function formatDuration(ms: number): string {
  return `${(ms / 1000).toFixed(1)}s`;
}

export function formatWebsearchCall(
  args: WebsearchCallArgs | undefined,
  provider: ProviderID | undefined,
  theme: any,
): string {
  const invalidArg = theme.fg("error", "[invalid arg]");
  let text = theme.fg("toolTitle", theme.bold("websearch "));
  text += args?.query ? theme.fg("accent", `"${args.query}"`) : invalidArg;
  if (provider) {
    text += theme.fg("muted", ` [${providerLabel(provider)}]`);
  }
  return text;
}

const PREVIEW_LINES = 5;

export class WebsearchResultRenderComponent extends Container {
  state = {
    cachedWidth: undefined as number | undefined,
    cachedLines: undefined as readonly string[] | undefined,
    cachedSkipped: undefined as number | undefined,
  };
}

export function rebuildWebsearchResultRenderComponent(
  component: WebsearchResultRenderComponent,
  result: { details?: WebsearchDetails; content: Array<{ type: string; text?: string }> },
  options: { expanded: boolean; isPartial: boolean },
  theme: any,
  state: WebsearchRenderState,
  isError: boolean,
  hints: KeybindingHints,
): void {
  const cState = component.state;
  component.clear();

  const details = result.details;

  if (options.isPartial) {
    let text = theme.fg("warning", "Searching...");
    if (details) {
      text = theme.fg("warning", `Searching via ${providerLabel(details.provider)}...`);
    }
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

  const label = providerLabel(details.provider);

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
  if (details.attempts && details.attempts > 1) {
    statusText += theme.fg("muted", ` (after ${details.attempts} providers)`);
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
      // Keep the first visual lines so higher-ranked hits remain visible.
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
              ` ${hints.keyHint("app.tools.expand", "to expand")})`;
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

  const truncation = details.truncation;
  const fullOutputPath = details.fullOutputPath;
  const fullOutputError = details.fullOutputError;
  if (truncation?.truncated || fullOutputPath || fullOutputError) {
    const warnings: string[] = [];
    if (fullOutputPath) {
      warnings.push(`Full output: ${fullOutputPath}`);
    } else if (fullOutputError) {
      warnings.push(`Could not save the full output: ${fullOutputError}`);
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
