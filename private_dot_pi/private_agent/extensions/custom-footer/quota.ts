import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { TUI } from "@mariozechner/pi-tui";

const CACHE_DIR = join(homedir(), ".cache", "pi-agent-footer");
const PI_AGENT_AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;
const RETRY_COOLDOWN_MS = 30 * 1000;

interface SyntheticQuota {
  rollingFiveHourLimit: {
    max: number;
    remaining: number;
    nextTickAt: string;
  };
  weeklyTokenLimit: {
    nextRegenAt: string;
    percentRemaining: number;
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

interface CodexQuota {
  rate_limit?: {
    primary_window?: {
      used_percent: number;
      reset_at: number;
    } | null;
    secondary_window?: {
      used_percent: number;
      reset_at: number;
    } | null;
  } | null;
}

interface ZaiQuota {
  data: {
    limits: Array<{
      type: "TOKENS_LIMIT" | "TIME_LIMIT";
      percentage: number;
      nextResetTime?: number;
    }>;
  };
}

interface CachedValue<T> {
  value: T;
  updatedAt: number;
}

interface QuotaSourceConfig<T> {
  cacheTtlMs: number;
  readAuth: () => Promise<string | null>;
  fetchQuota: (auth: string) => Promise<T | null>;
  formatQuota: (quota: T) => string | null;
}

interface QuotaSource {
  readText(): string | null;
  refresh(tui: TUI): Promise<void>;
}

function fresh<T>(
  cache: CachedValue<T> | null,
  ttlMs: number,
): CachedValue<T> | null {
  if (!cache || Date.now() - cache.updatedAt >= ttlMs) {
    return null;
  }

  return cache;
}

async function readJsonFile<T>(filePath: string): Promise<T | null> {
  try {
    const content = await readFile(filePath, "utf-8");
    return JSON.parse(content) as T;
  } catch {
    return null;
  }
}

async function fetchJson<T>(url: string, authToken: string): Promise<T | null> {
  try {
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    if (!response.ok) {
      return null;
    }
    return (await response.json()) as T;
  } catch {
    return null;
  }
}

function cachePath(provider: string): string {
  return join(CACHE_DIR, `${provider}-quota.json`);
}

async function readCache<T>(
  provider: string,
  ttlMs: number,
): Promise<CachedValue<T> | null> {
  return fresh(await readJsonFile<CachedValue<T>>(cachePath(provider)), ttlMs);
}

async function writeCache<T>(provider: string, value: T): Promise<void> {
  const filePath = cachePath(provider);
  await mkdir(CACHE_DIR, { recursive: true });
  await writeFile(
    filePath,
    JSON.stringify({ value, updatedAt: Date.now() } satisfies CachedValue<T>),
    "utf-8",
  );
}

async function readToken(
  provider: string,
  key: "access" | "refresh",
): Promise<string | null> {
  const auth =
    await readJsonFile<
      Record<string, Partial<Record<"access" | "refresh", string>>>
    >(PI_AGENT_AUTH_PATH);
  return auth?.[provider]?.[key] || null;
}

function formatTimeRemaining(targetDate: string | number): string {
  const targetTime =
    typeof targetDate === "number"
      ? targetDate
      : new Date(targetDate).getTime();
  const diff = targetTime - Date.now();

  if (diff <= 0) {
    return "0m";
  }

  const days = Math.floor(diff / DAY_MS);
  const hours = Math.floor((diff % DAY_MS) / HOUR_MS);
  const minutes = Math.floor((diff % HOUR_MS) / MINUTE_MS);

  if (days > 0) {
    if (hours > 0) {
      return `${days}d${hours}h`;
    }
    return `${days}d`;
  }
  if (hours > 0) {
    if (minutes > 0) {
      return `${hours}h${minutes}m`;
    }
    return `${hours}h`;
  }
  return `${minutes}m`;
}

function joinParts(
  parts: Array<string | null | undefined | false>,
): string | null {
  const filtered = parts.filter((part): part is string => Boolean(part));
  return filtered.length > 0 ? filtered.join(" ") : null;
}

function createQuotaSource<T>(
  provider: string,
  config: QuotaSourceConfig<T>,
): QuotaSource {
  let cache: CachedValue<T> | null = null;
  let fetching = false;
  let nextRetryAt = 0;

  async function loadQuota(): Promise<CachedValue<T> | null> {
    const cached =
      fresh(cache, config.cacheTtlMs) ??
      (await readCache<T>(provider, config.cacheTtlMs));
    if (cached) {
      return cached;
    }

    const auth = await config.readAuth();
    if (!auth) {
      nextRetryAt = Date.now() + RETRY_COOLDOWN_MS;
      return null;
    }

    const quota = await config.fetchQuota(auth);
    if (!quota) {
      nextRetryAt = Date.now() + RETRY_COOLDOWN_MS;
      return null;
    }

    const next = { value: quota, updatedAt: Date.now() };
    try {
      await writeCache(provider, quota);
    } catch {
      // Keep the in-memory value even if the disk cache cannot be updated.
    }

    return next;
  }

  return {
    readText(): string | null {
      const cached = fresh(cache, config.cacheTtlMs);
      return cached ? config.formatQuota(cached.value) : null;
    },
    async refresh(tui: TUI): Promise<void> {
      if (fetching || fresh(cache, config.cacheTtlMs)) {
        return;
      }
      if (Date.now() < nextRetryAt) {
        return;
      }

      fetching = true;
      try {
        const next = await loadQuota();
        if (!next) {
          return;
        }

        cache = next;
        nextRetryAt = 0;
        tui.requestRender();
      } finally {
        fetching = false;
      }
    },
  };
}

const quotaSources: Record<string, QuotaSource> = {
  synthetic: createQuotaSource("synthetic", {
    cacheTtlMs: MINUTE_MS,
    async readAuth(): Promise<string | null> {
      return process.env.SYNTHETIC_API_KEY || null;
    },
    async fetchQuota(apiKey: string): Promise<SyntheticQuota | null> {
      return fetchJson<SyntheticQuota>(
        "https://api.synthetic.new/v2/quotas",
        apiKey,
      );
    },
    formatQuota(quota: SyntheticQuota): string | null {
      const fiveHour = quota.rollingFiveHourLimit;
      const weekly = quota.weeklyTokenLimit;
      return joinParts([
        `${(fiveHour.max - fiveHour.remaining).toFixed(1)}/${fiveHour.max}/${formatTimeRemaining(fiveHour.nextTickAt)}`,
        `${(100 - weekly.percentRemaining).toFixed(1)}%/${formatTimeRemaining(weekly.nextRegenAt)}`,
      ]);
    },
  }),
  "github-copilot": createQuotaSource("github-copilot", {
    cacheTtlMs: 3 * MINUTE_MS,
    async readAuth(): Promise<string | null> {
      // curl -s "https://api.github.com/copilot_internal/user" -H "Authorization: Bearer $(jq -r '.[] | select(.oauth_token) | .oauth_token' ~/.config/github-copilot/apps.json | head -1)"
      return readToken("github-copilot", "refresh");
    },
    async fetchQuota(token: string): Promise<CopilotQuota | null> {
      return fetchJson<CopilotQuota>(
        "https://api.github.com/copilot_internal/user",
        token,
      );
    },
    formatQuota(quota: CopilotQuota): string | null {
      const premium = quota.quota_snapshots.premium_interactions;
      return `${premium.entitlement - premium.remaining}/${premium.entitlement} ${formatTimeRemaining(quota.quota_reset_date_utc)}`;
    },
  }),
  "openai-codex": createQuotaSource("openai-codex", {
    cacheTtlMs: MINUTE_MS,
    async readAuth(): Promise<string | null> {
      // curl -s -H "Authorization: Bearer $(cat ~/.codex/auth.json | jq -r '.tokens.access_token')" "https://chatgpt.com/backend-api/wham/usage" | jq .
      return readToken("openai-codex", "access");
    },
    async fetchQuota(token: string): Promise<CodexQuota | null> {
      return fetchJson<CodexQuota>(
        "https://chatgpt.com/backend-api/wham/usage",
        token,
      );
    },
    formatQuota(quota: CodexQuota): string | null {
      const rateLimit = quota.rate_limit;
      if (!rateLimit) {
        return null;
      }

      const formatWindow = (
        window:
          | {
              used_percent: number;
              reset_at: number;
            }
          | null
          | undefined,
      ): string | null =>
        window
          ? `${window.used_percent}% ${formatTimeRemaining(window.reset_at * 1000)}`
          : null;

      return joinParts([
        formatWindow(rateLimit.primary_window),
        formatWindow(rateLimit.secondary_window),
      ]);
    },
  }),
  zai: createQuotaSource("zai", {
    cacheTtlMs: 3 * MINUTE_MS,
    async readAuth(): Promise<string | null> {
      return process.env.ZAI_API_KEY || null;
    },
    async fetchQuota(apiKey: string): Promise<ZaiQuota | null> {
      return fetchJson<ZaiQuota>(
        "https://api.z.ai/api/monitor/usage/quota/limit",
        apiKey,
      );
    },
    formatQuota(quota: ZaiQuota): string | null {
      const tokens: string[] = [];
      const mcp: string[] = [];
      for (const limit of quota.data.limits) {
        if (limit.type === "TOKENS_LIMIT") {
          tokens.push(
            limit.nextResetTime
              ? `${limit.percentage}%/${formatTimeRemaining(limit.nextResetTime)}`
              : `${limit.percentage}%`,
          );
        } else if (limit.type === "TIME_LIMIT" && limit.percentage > 0) {
          mcp.push(`${limit.percentage}%`);
        }
      }
      return joinParts([...tokens, ...mcp]);
    },
  }),
};

export function readQuotaText(
  provider: string | undefined,
  tui: TUI,
): string | null {
  const quotaSource = provider ? quotaSources[provider] : null;
  if (!quotaSource) {
    return null;
  }

  const quotaText = quotaSource.readText();
  void quotaSource.refresh(tui);
  return quotaText;
}
