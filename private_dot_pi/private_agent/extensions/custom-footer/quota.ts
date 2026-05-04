import type { TUI } from "@mariozechner/pi-tui";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { formatDecimal } from "./utils.js";

const CACHE_DIR = join(homedir(), ".cache", "pi-agent-footer");
const PI_AGENT_AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");

const SECOND_MS = 1000;
const MINUTE_MS = 60 * SECOND_MS;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;
const RETRY_COOLDOWN_MS = 30 * 1000;

interface Theme {
  fg(color: string, text: string): string;
}

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

// https://portal.neuralwatt.com/docs/api/quota
interface NeuralwattQuota {
  balance: {
    credits_remaining_usd: number;
    total_credits_usd: number;
    credits_used_usd: number;
  };
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

interface DeepSeekQuota {
  balance_infos: Array<{
    currency: "CNY" | "USD";
    total_balance: string;
  }>;
}

interface CachedValue<T> {
  value: T;
  updatedAt: number;
}

interface SourceConfig<T> {
  cacheTtlMs: number;
  getAuth: () => Promise<string | null>;
  fetch: (auth: string) => Promise<T | null>;
  format: (quota: T, theme: Theme) => string | null;
}

interface Source {
  get(theme: Theme): string | null;
  refresh(tui: TUI): Promise<void>;
}

function fresh<T>(cache: CachedValue<T> | null, ttlMs: number): CachedValue<T> | null {
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

async function readCache<T>(provider: string, ttlMs: number): Promise<CachedValue<T> | null> {
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

async function readAuth(provider: string, key: "access" | "refresh"): Promise<string | null> {
  const auth =
    await readJson<Record<string, Partial<Record<"access" | "refresh", string>>>>(
      PI_AGENT_AUTH_PATH,
    );
  return auth?.[provider]?.[key] || null;
}

function formatRemaining(date: string | number): string {
  const time = typeof date === "number" ? date : new Date(date).getTime();
  const diff = time - Date.now();

  if (diff < SECOND_MS) {
    return diff <= 0 ? "0s" : "<1s";
  }

  const days = Math.floor(diff / DAY_MS);
  const hours = Math.floor((diff % DAY_MS) / HOUR_MS);
  const minutes = Math.floor((diff % HOUR_MS) / MINUTE_MS);
  const seconds = Math.floor((diff % MINUTE_MS) / SECOND_MS);

  if (days > 0) {
    return hours > 0 ? `${days}d${hours}h` : `${days}d`;
  }
  if (hours > 0) {
    return minutes > 0 ? `${hours}h${minutes}m` : `${hours}h`;
  }
  if (minutes > 0) {
    return `${minutes}m`;
  }
  return `${seconds}s`;
}

function joinParts(parts: Array<string | null | undefined | false>): string | null {
  const filtered = parts.filter((part): part is string => Boolean(part));
  return filtered.length > 0 ? filtered.join(" ") : null;
}

function createSource<T>(provider: string, config: SourceConfig<T>): Source {
  let cache: CachedValue<T> | null = null;
  let fetching = false;
  let nextRetryAt = 0;

  async function load(): Promise<CachedValue<T> | null> {
    const cached =
      fresh(cache, config.cacheTtlMs) ?? (await readCache<T>(provider, config.cacheTtlMs));
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
    get(theme: Theme): string | null {
      const cached = fresh(cache, config.cacheTtlMs);
      return cached ? config.format(cached.value, theme) : null;
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
      return fetchJson<SyntheticQuota>("https://api.synthetic.new/v2/quotas", apiKey);
    },
    format(quota: SyntheticQuota, theme: Theme): string | null {
      const fiveHour = quota.rollingFiveHourLimit;
      const weekly = quota.weeklyTokenLimit;
      return joinParts([
        `${theme.fg("accent", `${Math.round(fiveHour.max - fiveHour.remaining)}`)}${theme.fg("dim", `/${fiveHour.max}/${formatRemaining(fiveHour.nextTickAt)}`)}`,
        `${theme.fg("accent", `${formatDecimal(100 - weekly.percentRemaining, 1)}%`)}${theme.fg("dim", `/${formatRemaining(weekly.nextRegenAt)}`)}`,
      ]);
    },
  }),
  "github-copilot": createSource("github-copilot", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      // curl -s "https://api.github.com/copilot_internal/user" -H "Authorization: Bearer $(jq -r '.[] | select(.oauth_token) | .oauth_token' ~/.config/github-copilot/apps.json | head -1)"
      return readAuth("github-copilot", "refresh");
    },
    async fetch(token: string): Promise<CopilotQuota | null> {
      return fetchJson<CopilotQuota>("https://api.github.com/copilot_internal/user", token);
    },
    format(quota: CopilotQuota, theme: Theme): string | null {
      const premium = quota.quota_snapshots.premium_interactions;
      return `${theme.fg("accent", `${premium.entitlement - premium.remaining}`)}${theme.fg("dim", `/${premium.entitlement} ${formatRemaining(quota.quota_reset_date_utc)}`)}`;
    },
  }),
  "openai-codex": createSource("openai-codex", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      // curl -s -H "Authorization: Bearer $(cat ~/.codex/auth.json | jq -r '.tokens.access_token')" "https://chatgpt.com/backend-api/wham/usage" | jq .
      return readAuth("openai-codex", "access");
    },
    async fetch(token: string): Promise<CodexQuota | null> {
      return fetchJson<CodexQuota>("https://chatgpt.com/backend-api/wham/usage", token);
    },
    format(quota: CodexQuota, theme: Theme): string | null {
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
          ? `${theme.fg("accent", `${window.used_percent}%`)}${theme.fg("dim", `/${formatRemaining(window.reset_at * 1000)}`)}`
          : null;

      return joinParts([
        formatWindow(rateLimit.primary_window),
        formatWindow(rateLimit.secondary_window),
      ]);
    },
  }),
  neuralwatt: createSource("neuralwatt", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.NEURALWATT_API_KEY || null;
    },
    async fetch(apiKey: string): Promise<NeuralwattQuota | null> {
      return fetchJson<NeuralwattQuota>("https://api.neuralwatt.com/v1/quota", apiKey);
    },
    format(quota: NeuralwattQuota, theme: Theme): string | null {
      const bal = quota.balance;
      return `${theme.fg("accent", `$${formatDecimal(bal.credits_used_usd, 2)}`)}${theme.fg("dim", `/$${formatDecimal(bal.total_credits_usd, 2)}`)}`;
    },
  }),
  zai: createSource("zai", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.ZAI_API_KEY || null;
    },
    async fetch(apiKey: string): Promise<ZaiQuota | null> {
      return fetchJson<ZaiQuota>("https://api.z.ai/api/monitor/usage/quota/limit", apiKey);
    },
    format(quota: ZaiQuota, theme: Theme): string | null {
      const tokens: string[] = [];
      const mcp: string[] = [];
      for (const limit of quota.data.limits) {
        if (limit.type === "TOKENS_LIMIT") {
          tokens.push(
            limit.nextResetTime
              ? `${theme.fg("accent", `${limit.percentage}%`)}${theme.fg("dim", `/${formatRemaining(limit.nextResetTime)}`)}`
              : theme.fg("accent", `${limit.percentage}%`),
          );
        } else if (limit.type === "TIME_LIMIT" && limit.percentage > 0) {
          mcp.push(theme.fg("muted", `${limit.percentage}%`));
        }
      }
      return joinParts([...tokens, ...mcp]);
    },
  }),
  deepseek: createSource("deepseek", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.DEEPSEEK_API_KEY || null;
    },
    async fetch(apiKey: string): Promise<DeepSeekQuota | null> {
      return fetchJson<DeepSeekQuota>("https://api.deepseek.com/user/balance", apiKey);
    },
    format(quota: DeepSeekQuota, theme: Theme): string | null {
      return joinParts(
        quota.balance_infos
          .filter((b) => parseFloat(b.total_balance) > 0)
          .map((b) => {
            const symbol = b.currency === "CNY" ? "¥" : "$";
            return `${theme.fg("accent", `${symbol}${parseFloat(b.total_balance).toFixed(2)}`)}`;
          }),
      );
    },
  }),
};

export function getQuota(provider: string | undefined, tui: TUI, theme: Theme): string | null {
  const source = provider ? sources[provider] : null;
  if (!source) {
    return null;
  }

  const quota = source.get(theme);
  void source.refresh(tui);
  return quota;
}
