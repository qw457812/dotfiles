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

interface SourceConfig<T> {
  cacheTtlMs: number;
  getAuth: () => Promise<string | null>;
  fetch: (auth: string) => Promise<T | null>;
  format: (quota: T) => string | null;
}

interface Source {
  get(): string | null;
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

async function readJson<T>(path: string): Promise<T | null> {
  try {
    const content = await readFile(path, "utf-8");
    return JSON.parse(content) as T;
  } catch {
    return null;
  }
}

async function fetchJson<T>(url: string, token: string): Promise<T | null> {
  try {
    const resp = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!resp.ok) {
      return null;
    }
    return (await resp.json()) as T;
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
  return fresh(await readJson<CachedValue<T>>(cachePath(provider)), ttlMs);
}

async function writeCache<T>(provider: string, value: T): Promise<void> {
  const path = cachePath(provider);
  await mkdir(CACHE_DIR, { recursive: true });
  await writeFile(
    path,
    JSON.stringify({ value, updatedAt: Date.now() } satisfies CachedValue<T>),
    "utf-8",
  );
}

async function readAuth(
  provider: string,
  key: "access" | "refresh",
): Promise<string | null> {
  const auth =
    await readJson<
      Record<string, Partial<Record<"access" | "refresh", string>>>
    >(PI_AGENT_AUTH_PATH);
  return auth?.[provider]?.[key] || null;
}

function formatTime(date: string | number): string {
  const time = typeof date === "number" ? date : new Date(date).getTime();
  const diff = time - Date.now();

  if (diff <= 0) {
    return "0m";
  }

  const days = Math.floor(diff / DAY_MS);
  const hours = Math.floor((diff % DAY_MS) / HOUR_MS);
  const minutes = Math.floor((diff % HOUR_MS) / MINUTE_MS);

  if (days > 0) {
    return hours > 0 ? `${days}d${hours}h` : `${days}d`;
  }
  if (hours > 0) {
    return minutes > 0 ? `${hours}h${minutes}m` : `${hours}h`;
  }
  return `${minutes}m`;
}

function joinParts(
  parts: Array<string | null | undefined | false>,
): string | null {
  const filtered = parts.filter((part): part is string => Boolean(part));
  return filtered.length > 0 ? filtered.join(" ") : null;
}

function createSource<T>(provider: string, config: SourceConfig<T>): Source {
  let cache: CachedValue<T> | null = null;
  let fetching = false;
  let nextRetryAt = 0;

  async function load(): Promise<CachedValue<T> | null> {
    const cached =
      fresh(cache, config.cacheTtlMs) ??
      (await readCache<T>(provider, config.cacheTtlMs));
    if (cached) {
      return cached;
    }

    const auth = await config.getAuth();
    if (!auth) {
      nextRetryAt = Date.now() + RETRY_COOLDOWN_MS;
      return null;
    }

    const quota = await config.fetch(auth);
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
    get(): string | null {
      const cached = fresh(cache, config.cacheTtlMs);
      return cached ? config.format(cached.value) : null;
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
        const next = await load();
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

const sources: Record<string, Source> = {
  synthetic: createSource("synthetic", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.SYNTHETIC_API_KEY || null;
    },
    async fetch(apiKey: string): Promise<SyntheticQuota | null> {
      return fetchJson<SyntheticQuota>(
        "https://api.synthetic.new/v2/quotas",
        apiKey,
      );
    },
    format(quota: SyntheticQuota): string | null {
      const fiveHour = quota.rollingFiveHourLimit;
      const weekly = quota.weeklyTokenLimit;
      return joinParts([
        `${(fiveHour.max - fiveHour.remaining).toFixed(1)}/${fiveHour.max}/${formatTime(fiveHour.nextTickAt)}`,
        `${(100 - weekly.percentRemaining).toFixed(1)}%/${formatTime(weekly.nextRegenAt)}`,
      ]);
    },
  }),
  "github-copilot": createSource("github-copilot", {
    cacheTtlMs: 3 * MINUTE_MS,
    async getAuth(): Promise<string | null> {
      // curl -s "https://api.github.com/copilot_internal/user" -H "Authorization: Bearer $(jq -r '.[] | select(.oauth_token) | .oauth_token' ~/.config/github-copilot/apps.json | head -1)"
      return readAuth("github-copilot", "refresh");
    },
    async fetch(token: string): Promise<CopilotQuota | null> {
      return fetchJson<CopilotQuota>(
        "https://api.github.com/copilot_internal/user",
        token,
      );
    },
    format(quota: CopilotQuota): string | null {
      const premium = quota.quota_snapshots.premium_interactions;
      return `${premium.entitlement - premium.remaining}/${premium.entitlement} ${formatTime(quota.quota_reset_date_utc)}`;
    },
  }),
  "openai-codex": createSource("openai-codex", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      // curl -s -H "Authorization: Bearer $(cat ~/.codex/auth.json | jq -r '.tokens.access_token')" "https://chatgpt.com/backend-api/wham/usage" | jq .
      return readAuth("openai-codex", "access");
    },
    async fetch(token: string): Promise<CodexQuota | null> {
      return fetchJson<CodexQuota>(
        "https://chatgpt.com/backend-api/wham/usage",
        token,
      );
    },
    format(quota: CodexQuota): string | null {
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
          ? `${window.used_percent}% ${formatTime(window.reset_at * 1000)}`
          : null;

      return joinParts([
        formatWindow(rateLimit.primary_window),
        formatWindow(rateLimit.secondary_window),
      ]);
    },
  }),
  zai: createSource("zai", {
    cacheTtlMs: 3 * MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.ZAI_API_KEY || null;
    },
    async fetch(apiKey: string): Promise<ZaiQuota | null> {
      return fetchJson<ZaiQuota>(
        "https://api.z.ai/api/monitor/usage/quota/limit",
        apiKey,
      );
    },
    format(quota: ZaiQuota): string | null {
      const tokens: string[] = [];
      const mcp: string[] = [];
      for (const limit of quota.data.limits) {
        if (limit.type === "TOKENS_LIMIT") {
          tokens.push(
            limit.nextResetTime
              ? `${limit.percentage}%/${formatTime(limit.nextResetTime)}`
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

export function getQuota(
  provider: string | undefined,
  tui: TUI,
): string | null {
  const source = provider ? sources[provider] : null;
  if (!source) {
    return null;
  }

  const quota = source.get();
  void source.refresh(tui);
  return quota;
}
