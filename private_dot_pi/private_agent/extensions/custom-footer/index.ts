/**
 * Custom footer extension - compact variant of the default footer.
 *
 * Differences from default:
 * - No pwd/branch/session name line (cleaner look)
 * - No "(auto)" compaction indicator
 *
 * Shows:
 * - Token usage: ↑input ↓output Rcache_read Wcache_write
 * - Cost: $N.NN
 * - TPS/TTFT: session-average tokens per second / time to first token
 * - Context usage: N% (colored: green/yellow/red based on usage)
 * - Quota info for certain providers (when active)
 * - Elapsed: session duration
 * - Version
 * - Model name, provider (when multi-provider), thinking level
 * - Tool tally (if any)
 * - Extension status messages (if any)
 *
 * Ref:
 * - Example extension: https://github.com/badlogic/pi-mono/blob/7b902612e96a8bf49cf6f34345f09a44e5ca6926/packages/coding-agent/examples/extensions/custom-footer.ts
 * - Default footer: https://github.com/badlogic/pi-mono/blob/3de8c48692ba2fd9f23d9cd0b99299edbe46af80/packages/coding-agent/src/modes/interactive/components/footer.ts
 * - oh-pi footer: https://github.com/telagod/oh-pi/blob/21c06f2d577eb6129582d1f9bb1e0f3bb98ed5c4/pi-package/extensions/custom-footer.ts
 */

import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
} from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";
import { type TUI, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { getQuota } from "./quota.js";
import { createToolCounter } from "./tool-counter.js";
import { createTpsTracker } from "./tps.js";
import { formatDecimal, formatTokens } from "./utils.js";

export default function (pi: ExtensionAPI) {
  let enabled = true;
  let sessionStart = Date.now();
  const tpsTracker = createTpsTracker();
  const toolCounter = createToolCounter();

  function formatElapsed(ms: number): string {
    const s = Math.floor(ms / 1000);
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    const rs = s % 60;
    if (m < 60) return `${m}m${rs > 0 ? rs + "s" : ""}`;
    const h = Math.floor(m / 60);
    const rm = m % 60;
    return `${h}h${rm > 0 ? rm + "m" : ""}`;
  }

  /**
   * Sanitize text for display in a single-line status.
   * Removes newlines, tabs, carriage returns, and other control characters.
   */
  function sanitizeStatusText(text: string): string {
    // Replace newlines, tabs, carriage returns with space, then collapse multiple spaces
    return text
      .replace(/[\r\n\t]/g, " ")
      .replace(/ +/g, " ")
      .trim();
  }

  function createFooterFactory(ctx: ExtensionContext) {
    return (
      tui: TUI,
      theme: { fg(color: string, text: string): string },
      footerData: ReadonlyFooterDataProvider,
    ) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());
      const timer = setInterval(() => tui.requestRender(), 30000);

      return {
        dispose() {
          unsub();
          clearInterval(timer);
        },
        invalidate() {},
        render(width: number): string[] {
          // Calculate cumulative usage from ALL session entries (not just post-compaction messages)
          let totalInput = 0;
          let totalOutput = 0;
          let totalCacheRead = 0;
          let totalCacheWrite = 0;
          let totalCost = 0;

          for (const entry of ctx.sessionManager.getEntries()) {
            if (entry.type === "message" && entry.message.role === "assistant") {
              totalInput += entry.message.usage.input;
              totalOutput += entry.message.usage.output;
              totalCacheRead += entry.message.usage.cacheRead;
              totalCacheWrite += entry.message.usage.cacheWrite;
              totalCost += entry.message.usage.cost.total;
            }
          }

          // Calculate context usage from session
          const contextUsage = ctx.getContextUsage();
          const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
          const contextPercentValue = contextUsage?.percent ?? 0;
          const contextPercent =
            contextUsage?.percent !== null ? formatDecimal(contextPercentValue, 1) : "?";

          // Build stats line
          const statsParts = [];
          if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
          if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
          if (totalCacheRead) statsParts.push(`R${formatTokens(totalCacheRead)}`);
          if (totalCacheWrite) statsParts.push(`W${formatTokens(totalCacheWrite)}`);

          // Cost (without "(sub)" indicator - not accessible from extension)
          if (totalCost) {
            statsParts.push(`$${formatDecimal(totalCost, 2)}`);
          }

          // Session-average TPS/TTFT
          const tps = tpsTracker.getTps(theme);
          if (tps) {
            statsParts.push(tps);
          }

          // Colorize context percentage based on usage
          const contextPercentColor =
            contextPercentValue > 75 ? "error" : contextPercentValue > 50 ? "warning" : "success";
          const contextPercentStr =
            theme.fg(contextPercentColor, contextPercent === "?" ? "?" : `${contextPercent}%`) +
            theme.fg("dim", `/${formatTokens(contextWindow)}`);
          statsParts.push(contextPercentStr);

          // Quota
          const quota = getQuota(ctx.model?.provider, tui, theme);
          if (quota) {
            statsParts.push(quota);
          }

          // Version
          statsParts.push(theme.fg("dim", `v${VERSION}`));

          // Elapsed
          statsParts.push(theme.fg("dim", formatElapsed(Date.now() - sessionStart)));

          let statsLeft = statsParts.join(" ");

          // Add model name on the right side, plus thinking level if model supports it
          const modelName = ctx.model?.id || "no-model";

          let statsLeftWidth = visibleWidth(statsLeft);

          // If statsLeft is too wide, truncate it
          if (statsLeftWidth > width) {
            statsLeft = truncateToWidth(statsLeft, width, "…");
            statsLeftWidth = visibleWidth(statsLeft);
          }

          // Calculate available space for padding (minimum 2 spaces between stats and model)
          const minPadding = 2;

          // Add thinking level indicator if model supports reasoning
          let rightSideWithoutProvider = modelName;
          if (ctx.model?.reasoning) {
            const thinkingLevel = pi.getThinkingLevel() || "off";
            rightSideWithoutProvider =
              thinkingLevel === "off"
                ? `${modelName} thinking off`
                : `${modelName} ${thinkingLevel}`;
          }

          // Prepend the provider in parentheses if there are multiple providers and there's enough room
          let rightSide = rightSideWithoutProvider;
          if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
            rightSide = `${ctx.model.provider} ${rightSideWithoutProvider}`;
            if (statsLeftWidth + minPadding + visibleWidth(rightSide) > width) {
              // Too wide, fall back
              rightSide = rightSideWithoutProvider;
            }
          }

          const rightSideWidth = visibleWidth(rightSide);
          const totalNeeded = statsLeftWidth + minPadding + rightSideWidth;

          let statsLine: string;
          if (totalNeeded <= width) {
            // Both fit - add padding to right-align model
            const padding = " ".repeat(width - statsLeftWidth - rightSideWidth);
            statsLine = statsLeft + padding + rightSide;
          } else {
            // Need to truncate right side
            const availableForRight = width - statsLeftWidth - minPadding;
            if (availableForRight > 0) {
              const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
              const truncatedRightWidth = visibleWidth(truncatedRight);
              const padding = " ".repeat(Math.max(0, width - statsLeftWidth - truncatedRightWidth));
              statsLine = statsLeft + padding + truncatedRight;
            } else {
              // Not enough space for right side at all
              statsLine = statsLeft;
            }
          }

          // Apply dim to each part separately. statsLeft may contain color codes (for context %)
          // that end with a reset, which would clear an outer dim wrapper. So we dim the parts
          // before and after the colored section independently.
          const dimStatsLeft = theme.fg("dim", statsLeft);
          const remainder = statsLine.slice(statsLeft.length); // padding + rightSide
          const dimRemainder = theme.fg("dim", remainder);

          const lines = [dimStatsLeft + dimRemainder];

          // Tool tally line
          const toolTally = toolCounter.getToolTally(theme);
          if (toolTally) {
            lines.push(truncateToWidth(toolTally, width, theme.fg("dim", "…")));
          }

          // Add extension statuses on a single line, sorted by key alphabetically
          const extensionStatuses = footerData.getExtensionStatuses();
          if (extensionStatuses.size > 0) {
            const sortedStatuses = Array.from(extensionStatuses.entries())
              .sort(([a], [b]) => a.localeCompare(b))
              .map(([, text]) => sanitizeStatusText(text));
            const statusLine = sortedStatuses.join(" ");
            // Truncate to terminal width with dim ellipsis for consistency with footer style
            lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "…")));
          }

          return lines;
        },
      };
    };
  }

  // Set custom footer on startup
  pi.on("session_start", (_event, ctx) => {
    sessionStart = Date.now();

    ctx.ui.setFooter(createFooterFactory(ctx));

    tpsTracker.onSessionStart();
    toolCounter.onSessionStart();
  });

  pi.on("agent_start", () => {
    tpsTracker.onAgentStart();
  });

  pi.on("turn_start", () => {
    tpsTracker.onTurnStart();
  });

  pi.on("message_update", (event) => {
    tpsTracker.onMessageUpdate(event);
  });

  pi.on("message_end", (event) => {
    tpsTracker.onMessageEnd(event);
  });

  pi.on("turn_end", () => {
    tpsTracker.onTurnEnd();
  });

  pi.on("agent_end", (event, ctx) => {
    tpsTracker.onAgentEnd(event, ctx);
  });

  pi.on("tool_execution_end", (event) => {
    toolCounter.onToolExecutionEnd(event);
  });

  pi.registerCommand("footer", {
    description: "Toggle custom footer",
    handler: async (_args, ctx) => {
      enabled = !enabled;

      if (enabled) {
        ctx.ui.setFooter(createFooterFactory(ctx));
        ctx.ui.notify("Custom footer enabled", "info");
      } else {
        ctx.ui.setFooter(undefined);
        ctx.ui.notify("Default footer restored", "info");
      }
    },
  });
}
