/**
 * Custom footer extension - compact variant of the default footer.
 *
 * Differences from default:
 * - No pwd/branch/session name line (cleaner look)
 * - No "(auto)" compaction indicator
 *
 * Shows:
 * - Token usage: ↑input ↓output Rcache_read Wcache_write
 * - Cost: $N.NNN
 * - Context usage: N% (colored: green/yellow/red based on usage)
 * - Model name, provider (when multi-provider), thinking level
 * - Extension status messages (if any)
 *
 * Ref:
 * - Original example: https://github.com/badlogic/pi-mono/blob/7b902612e96a8bf49cf6f34345f09a44e5ca6926/packages/coding-agent/examples/extensions/custom-footer.ts
 * - Default footer: https://github.com/badlogic/pi-mono/blob/3de8c48692ba2fd9f23d9cd0b99299edbe46af80/packages/coding-agent/src/modes/interactive/components/footer.ts
 */

import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
} from "@mariozechner/pi-coding-agent";
import { type TUI, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

export default function (pi: ExtensionAPI) {
  let enabled = true;

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

  /**
   * Format token counts (similar to web-ui)
   */
  function formatTokens(count: number): string {
    if (count < 1000) return count.toString();
    if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
    if (count < 1000000) return `${Math.round(count / 1000)}k`;
    if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
    return `${Math.round(count / 1000000)}M`;
  }

  function createFooterFactory(ctx: ExtensionContext) {
    return (
      tui: TUI,
      theme: { fg(color: string, text: string): string },
      footerData: ReadonlyFooterDataProvider,
    ) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          // Calculate cumulative usage from ALL session entries (not just post-compaction messages)
          let totalInput = 0;
          let totalOutput = 0;
          let totalCacheRead = 0;
          let totalCacheWrite = 0;
          let totalCost = 0;

          for (const entry of ctx.sessionManager.getEntries()) {
            if (
              entry.type === "message" &&
              entry.message.role === "assistant"
            ) {
              totalInput += entry.message.usage.input;
              totalOutput += entry.message.usage.output;
              totalCacheRead += entry.message.usage.cacheRead;
              totalCacheWrite += entry.message.usage.cacheWrite;
              totalCost += entry.message.usage.cost.total;
            }
          }

          // Calculate context usage from session
          const contextUsage = ctx.getContextUsage();
          const contextWindow =
            contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
          const contextPercentValue = contextUsage?.percent ?? 0;
          const contextPercent =
            contextUsage?.percent !== null
              ? contextPercentValue.toFixed(1)
              : "?";

          // Build stats line
          const statsParts = [];
          if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
          if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
          if (totalCacheRead)
            statsParts.push(`R${formatTokens(totalCacheRead)}`);
          if (totalCacheWrite)
            statsParts.push(`W${formatTokens(totalCacheWrite)}`);

          // Cost (without "(sub)" indicator - not accessible from extension)
          if (totalCost) {
            statsParts.push(`$${totalCost.toFixed(3)}`);
          }

          // Colorize context percentage based on usage
          let contextPercentStr: string;
          const contextPercentDisplay =
            contextPercent === "?"
              ? `?/${formatTokens(contextWindow)}`
              : `${contextPercent}%/${formatTokens(contextWindow)}`;
          if (contextPercentValue > 90) {
            contextPercentStr = theme.fg("error", contextPercentDisplay);
          } else if (contextPercentValue > 70) {
            contextPercentStr = theme.fg("warning", contextPercentDisplay);
          } else {
            contextPercentStr = contextPercentDisplay;
          }
          statsParts.push(contextPercentStr);

          let statsLeft = statsParts.join(" ");

          // Add model name on the right side, plus thinking level if model supports it
          const modelName = ctx.model?.id || "no-model";

          let statsLeftWidth = visibleWidth(statsLeft);

          // If statsLeft is too wide, truncate it
          if (statsLeftWidth > width) {
            statsLeft = truncateToWidth(statsLeft, width, "...");
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
                ? `${modelName} • thinking off`
                : `${modelName} • ${thinkingLevel}`;
          }

          // Prepend the provider in parentheses if there are multiple providers and there's enough room
          let rightSide = rightSideWithoutProvider;
          if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
            rightSide = `(${ctx.model.provider}) ${rightSideWithoutProvider}`;
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
              const truncatedRight = truncateToWidth(
                rightSide,
                availableForRight,
                "",
              );
              const truncatedRightWidth = visibleWidth(truncatedRight);
              const padding = " ".repeat(
                Math.max(0, width - statsLeftWidth - truncatedRightWidth),
              );
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

          // Add extension statuses on a single line, sorted by key alphabetically
          const extensionStatuses = footerData.getExtensionStatuses();
          if (extensionStatuses.size > 0) {
            const sortedStatuses = Array.from(extensionStatuses.entries())
              .sort(([a], [b]) => a.localeCompare(b))
              .map(([, text]) => sanitizeStatusText(text));
            const statusLine = sortedStatuses.join(" ");
            // Truncate to terminal width with dim ellipsis for consistency with footer style
            lines.push(
              truncateToWidth(statusLine, width, theme.fg("dim", "...")),
            );
          }

          return lines;
        },
      };
    };
  }

  // Set custom footer on startup
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setFooter(createFooterFactory(ctx));
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
