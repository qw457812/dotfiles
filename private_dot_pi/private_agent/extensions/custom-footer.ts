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
 * - Quota info for Synthetic/Copilot providers (when active)
 *
 * Ref:
 * - Original example: https://github.com/badlogic/pi-mono/blob/7b902612e96a8bf49cf6f34345f09a44e5ca6926/packages/coding-agent/examples/extensions/custom-footer.ts
 * - Default footer: https://github.com/badlogic/pi-mono/blob/3de8c48692ba2fd9f23d9cd0b99299edbe46af80/packages/coding-agent/src/modes/interactive/components/footer.ts
 */

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
} from "@mariozechner/pi-coding-agent";
import { type TUI, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

// Cache directory for provider quota snapshots.
const CACHE_DIR = join(homedir(), ".cache", "pi-agent-footer");
const COPILOT_APPS_PATH = join(
  homedir(),
  ".config",
  "github-copilot",
  "apps.json",
);
const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

interface SyntheticQuota {
  subscription: {
    limit: number;
    requests: number;
    renewsAt: string;
  };
  freeToolCalls: {
    limit: number;
    requests: number;
    renewsAt: string;
  };
}

interface CopilotQuota {
  quota_snapshots: {
    premium_interactions: {
      entitlement: number;
      remaining: number;
    };
  };
  quota_reset_date_utc: string;
}

interface CachedValue<T> {
  value: T;
  updatedAt: number;
}

interface QuotaProviderSpec<T> {
  cacheKey: string;
  cacheTtlMs: number;
  retryCooldownMs: number;
  readAuth: () => Promise<string | null>;
  fetchQuota: (auth: string) => Promise<T | null>;
  formatQuota: (quota: T) => string;
}

interface QuotaProviderState<T> {
  cache: CachedValue<T> | null;
  fetching: boolean;
  nextRetryAt: number;
}

interface QuotaProviderRuntime {
  getText(): string | null;
  refresh(tui: TUI): Promise<void>;
}

interface CacheStore<T> {
  readFresh(ttlMs: number): Promise<CachedValue<T> | null>;
  write(value: T): Promise<void>;
}

function createCachedValue<T>(value: T): CachedValue<T> {
  return { value, updatedAt: Date.now() };
}

function isCacheFresh<T>(
  cache: CachedValue<T> | null,
  ttlMs: number,
): cache is CachedValue<T> {
  if (!cache) return false;
  return Date.now() - cache.updatedAt < ttlMs;
}

function formatTimeRemaining(targetDate: string): string {
  const now = Date.now();
  const target = new Date(targetDate).getTime();
  const diff = target - now;

  if (diff <= 0) return "0m";

  const days = Math.floor(diff / DAY_MS);
  const hours = Math.floor((diff % DAY_MS) / HOUR_MS);
  const minutes = Math.floor((diff % HOUR_MS) / MINUTE_MS);

  if (days > 0) {
    return `${days}d${hours}h${minutes}m`;
  }
  if (hours > 0) {
    return `${hours}h${minutes}m`;
  }
  return `${minutes}m`;
}

async function getSyntheticApiKey(): Promise<string | null> {
  return process.env.SYNTHETIC_API_KEY || null;
}

async function getCopilotToken(): Promise<string | null> {
  try {
    const content = await readFile(COPILOT_APPS_PATH, "utf-8");
    const apps = JSON.parse(content) as Record<
      string,
      { oauth_token?: string }
    >;
    // apps.json is an object with host:app keys, values contain oauth_token
    const app = Object.values(apps).find((a) => a.oauth_token);
    return app?.oauth_token || null;
  } catch {
    return null;
  }
}

async function fetchSyntheticQuota(
  apiKey: string,
): Promise<SyntheticQuota | null> {
  try {
    const response = await fetch("https://api.synthetic.new/v2/quotas", {
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    if (!response.ok) return null;
    return (await response.json()) as SyntheticQuota;
  } catch {
    return null;
  }
}

async function fetchCopilotQuota(token: string): Promise<CopilotQuota | null> {
  try {
    const response = await fetch(
      "https://api.github.com/copilot_internal/user",
      {
        headers: { Authorization: `Bearer ${token}` },
      },
    );
    if (!response.ok) return null;
    return (await response.json()) as CopilotQuota;
  } catch {
    return null;
  }
}

function formatQuotaUsage(
  used: number,
  limit: number,
  renewsAt: string,
): string {
  return `${used}/${limit} ${formatTimeRemaining(renewsAt)}`;
}

function formatSyntheticQuota(quota: SyntheticQuota): string {
  const sub = quota.subscription;
  const tool = quota.freeToolCalls;
  return [
    formatQuotaUsage(sub.requests, sub.limit, sub.renewsAt),
    formatQuotaUsage(tool.requests, tool.limit, tool.renewsAt),
  ].join(" ");
}

function formatCopilotQuota(quota: CopilotQuota): string {
  const premium = quota.quota_snapshots.premium_interactions;
  const used = premium.entitlement - premium.remaining;
  return formatQuotaUsage(
    used,
    premium.entitlement,
    quota.quota_reset_date_utc,
  );
}

function createCacheStore<T>(cacheKey: string): CacheStore<T> {
  const filePath = join(CACHE_DIR, `${cacheKey}.json`);

  return {
    async readFresh(ttlMs: number): Promise<CachedValue<T> | null> {
      try {
        const content = await readFile(filePath, "utf-8");
        const cache = JSON.parse(content) as CachedValue<T>;
        return isCacheFresh(cache, ttlMs) ? cache : null;
      } catch {
        return null;
      }
    },
    async write(value: T): Promise<void> {
      await mkdir(CACHE_DIR, { recursive: true });
      await writeFile(
        filePath,
        JSON.stringify(createCachedValue(value)),
        "utf-8",
      );
    },
  };
}

function createQuotaProvider<T>(
  spec: QuotaProviderSpec<T>,
): QuotaProviderRuntime {
  const cacheStore = createCacheStore<T>(spec.cacheKey);
  const state: QuotaProviderState<T> = {
    cache: null,
    fetching: false,
    nextRetryAt: 0,
  };

  function scheduleRetry(): void {
    state.nextRetryAt = Date.now() + spec.retryCooldownMs;
  }

  function updateCache(cache: CachedValue<T>): void {
    state.cache = cache;
    state.nextRetryAt = 0;
  }

  async function loadCachedQuota(): Promise<boolean> {
    const cached = await cacheStore.readFresh(spec.cacheTtlMs);
    if (!cached) {
      return false;
    }

    updateCache(cached);
    return true;
  }

  async function fetchAndCacheQuota(): Promise<boolean> {
    const auth = await spec.readAuth();
    if (!auth) {
      scheduleRetry();
      return false;
    }

    const quota = await spec.fetchQuota(auth);
    if (!quota) {
      scheduleRetry();
      return false;
    }

    updateCache(createCachedValue(quota));

    try {
      await cacheStore.write(quota);
    } catch {
      // Keep the in-memory value even if the disk cache cannot be updated.
    }

    return true;
  }

  return {
    getText() {
      const cachedQuota = state.cache;
      if (!isCacheFresh(cachedQuota, spec.cacheTtlMs)) {
        return null;
      }

      return spec.formatQuota(cachedQuota.value);
    },
    async refresh(tui: TUI): Promise<void> {
      if (
        isCacheFresh(state.cache, spec.cacheTtlMs) ||
        state.fetching ||
        Date.now() < state.nextRetryAt
      ) {
        return;
      }

      state.fetching = true;
      try {
        const didUpdate =
          (await loadCachedQuota()) || (await fetchAndCacheQuota());
        if (didUpdate) {
          tui.requestRender();
        }
      } finally {
        state.fetching = false;
      }
    },
  };
}

const QUOTA_PROVIDERS: Record<string, QuotaProviderRuntime> = {
  synthetic: createQuotaProvider({
    cacheKey: "synthetic-quota",
    cacheTtlMs: MINUTE_MS,
    retryCooldownMs: 30 * 1000,
    readAuth: getSyntheticApiKey,
    fetchQuota: fetchSyntheticQuota,
    formatQuota: formatSyntheticQuota,
  }),
  "github-copilot": createQuotaProvider({
    cacheKey: "github-copilot-quota",
    cacheTtlMs: 3 * MINUTE_MS,
    retryCooldownMs: 30 * 1000,
    readAuth: getCopilotToken,
    fetchQuota: fetchCopilotQuota,
    formatQuota: formatCopilotQuota,
  }),
};

function getQuotaText(provider: string | undefined, tui: TUI): string | null {
  if (!provider) {
    return null;
  }

  const quotaProvider = QUOTA_PROVIDERS[provider];
  if (!quotaProvider) {
    return null;
  }

  const quotaText = quotaProvider.getText();
  void quotaProvider.refresh(tui);
  return quotaText;
}

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

          const quotaText = getQuotaText(ctx.model?.provider, tui);
          if (quotaText) {
            statsParts.push(quotaText);
          }

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
