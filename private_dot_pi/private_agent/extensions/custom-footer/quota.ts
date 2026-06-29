import type { OAuthCredentials } from "@earendil-works/pi-ai";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { createReadStream, type Dirent } from "node:fs";
import { mkdir, readdir, readFile, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import readline from "node:readline";
import { formatDecimal, formatTokens } from "./utils.js";

const CACHE_DIR = join(homedir(), ".cache", "pi-agent-footer");
const PI_AGENT_AUTH_PATH = join(getAgentDir(), "auth.json");
const PI_AGENT_SESSIONS_DIR = join(getAgentDir(), "sessions");
const IS_TERMUX = Boolean(process.env.TERMUX_VERSION);

const SECOND_MS = 1000;
const MINUTE_MS = 60 * SECOND_MS;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;
const FETCH_TIMEOUT_MS = 15 * SECOND_MS;
const BASE_RETRY_DELAY_MS = 30 * SECOND_MS;
const MAX_RETRY_DELAY_MS = 4 * MINUTE_MS;

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

interface CodexQuotaWindow {
  used_percent: number;
  reset_at: number;
}

interface CodexQuota {
  quota: {
    rate_limit?: {
      primary_window?: CodexQuotaWindow | null;
      secondary_window?: CodexQuotaWindow | null;
    } | null;
    rate_limit_reset_credits?: {
      available_count?: number;
    } | null;
  } | null;
  reset: {
    available_count?: number;
    credits?: Array<{
      status?: string;
      expires_at?: string | null;
    }> | null;
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

// Xiaomi MiMo pay-as-you-go
interface XiaomiQuota {
  code: number;
  data?: {
    balance: string;
    currency: string;
  };
}

interface CrofQuota {
  credits: number;
}

interface SmartaipiQuota {
  credits: number;
  free_credits: number;
}

interface FreemodelQuotaWindow {
  usedCents: number;
  limitCents: number;
  resetsAt?: number;
}

interface FreemodelQuota {
  totalRequests?: number;
  totalTokens?: number;
  todayCacheReadTokens?: number;
  todayCacheWriteTokens?: number;
  window5h?: FreemodelQuotaWindow;
  windowWeek?: FreemodelQuotaWindow;
}

interface CodebuddyQuota {
  code: number;
  data: {
    credit: number;
    limitNum: number;
    cycleResetTime: string;
  };
}

type CodebuddyOAuthCredentials = {
  enterpriseId?: string;
} & OAuthCredentials;

// https://github.com/mikeyobrien/pi-provider-kiro/blob/77366aa27d76cdaa2a6d712a61120657788c4b06/src/usage.ts
interface KiroQuota {
  usageBreakdownList?: Array<{
    currentUsage: number;
    currentUsageWithPrecision?: number;
    usageLimit: number;
    usageLimitWithPrecision?: number;
    nextDateReset?: number | string;
  }>;
}

type KiroOAuthCredentials = {
  region?: string;
} & OAuthCredentials;

// Fire Pass V2 is unlimited
interface FirepassUsage {
  tokens: number;
  cost: number;
}

interface CachedValue<T> {
  value: T;
  updatedAt: number;
}

interface SourceConfig<T, A = string> {
  cacheTtlMs: number;
  getAuth: () => Promise<A | null>;
  fetch: (auth: A) => Promise<T | null>;
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
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!resp.ok) return null;
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

async function readAuth<T = Record<string, unknown>>(provider: string): Promise<T | null> {
  const auth = await readJson<Record<string, T>>(PI_AGENT_AUTH_PATH);
  return auth?.[provider] ?? null;
}

function formatRemaining(date: string | number): string {
  const time = typeof date === "number" ? date : new Date(date).getTime();
  if (!Number.isFinite(time)) return "?";

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

function joinParts(
  parts: Array<string | null | undefined | false>,
  separator = " ",
): string | null {
  const filtered = parts.filter((part): part is string => Boolean(part));
  return filtered.length > 0 ? filtered.join(separator) : null;
}

function toLocalDayKey(d: Date): string {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function readNum(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  if (typeof v === "string") {
    const trimmed = v.trim();
    if (!trimmed) return null;
    const n = Number(trimmed);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

// alternative: `firectl --api-key $FIREWORKS_API_KEY billing export-metrics --start-time "2026-05-16" --end-time "2026-05-17"`
async function getDailyFirepassUsage(): Promise<FirepassUsage> {
  const today = toLocalDayKey(new Date());
  let tokens = 0;
  let cost = 0;

  async function walk(dir: string) {
    let entries: Dirent[] = [];
    try {
      entries = await readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const ent of entries) {
      const p = join(dir, ent.name);
      if (ent.isDirectory()) {
        await walk(p);
        continue;
      }
      if (!ent.isFile() || !ent.name.endsWith(".jsonl")) continue;

      try {
        const st = await stat(p);
        const mtimeDate = toLocalDayKey(new Date(st.mtime));
        if (mtimeDate !== today) continue;
      } catch {
        continue;
      }

      try {
        const stream = createReadStream(p, { encoding: "utf8" });
        const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
        try {
          for await (const line of rl) {
            if (!line.trim()) continue;
            let entry: any;
            try {
              entry = JSON.parse(line);
            } catch {
              continue;
            }

            if (entry.type !== "message") continue;
            const msg = entry.message;
            if (!msg || msg.role !== "assistant") continue;
            if (msg.provider !== "firepass") continue;
            const usage = msg.usage;
            if (!usage) continue;

            // Tokens: prefer direct total, fall back to sum of parts
            const total = readNum(usage.totalTokens);
            let t = 0;
            if (total !== null) {
              t = total;
            } else {
              const input = readNum(usage.input) ?? 0;
              const output = readNum(usage.output) ?? 0;
              const cacheRead = readNum(usage.cacheRead) ?? 0;
              const cacheWrite = readNum(usage.cacheWrite) ?? 0;
              t = input + output + cacheRead + cacheWrite;
            }
            t = Number.isFinite(t) ? t : 0;

            // Cost
            const c = readNum(usage.cost?.total) ?? 0;

            const entryTs = entry.timestamp || msg.timestamp;
            if (!entryTs) continue;
            const entryDate = toLocalDayKey(new Date(entryTs));
            if (entryDate === today) {
              tokens += t;
              cost += c;
            }
          }
        } finally {
          rl.close();
          stream.destroy();
        }
      } catch {
        // Skip unreadable files
        continue;
      }
    }
  }

  await walk(PI_AGENT_SESSIONS_DIR);
  return { tokens, cost };
}

function createSource<T, A = string>(provider: string, config: SourceConfig<T, A>): Source {
  let cache: CachedValue<T> | null = null;
  let fetching = false;
  let nextRetryAt = 0;
  let retryDelayMs = BASE_RETRY_DELAY_MS;

  async function load(): Promise<CachedValue<T> | null> {
    const cached =
      fresh(cache, config.cacheTtlMs) ?? (await readCache<T>(provider, config.cacheTtlMs));
    if (cached) {
      nextRetryAt = 0;
      retryDelayMs = BASE_RETRY_DELAY_MS;
      return cached;
    }

    const auth = await config.getAuth();
    if (!auth) {
      nextRetryAt = Date.now() + BASE_RETRY_DELAY_MS;
      retryDelayMs = BASE_RETRY_DELAY_MS;
      return null;
    }

    const quota = await config.fetch(auth);
    if (!quota) {
      nextRetryAt = Date.now() + retryDelayMs;
      retryDelayMs = Math.min(retryDelayMs * 2, MAX_RETRY_DELAY_MS);
      return null;
    }

    retryDelayMs = BASE_RETRY_DELAY_MS;

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
      const data = await fetchJson<SyntheticQuota>("https://api.synthetic.new/v2/quotas", apiKey);
      return data?.rollingFiveHourLimit ? data : null;
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
      return (await readAuth<{ refresh?: string }>("github-copilot"))?.refresh ?? null;
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
      return (await readAuth<{ access?: string }>("openai-codex"))?.access ?? null;
    },
    async fetch(token: string): Promise<CodexQuota | null> {
      const [quota, reset] = await Promise.all([
        fetchJson<CodexQuota["quota"]>("https://chatgpt.com/backend-api/wham/usage", token),
        fetchJson<CodexQuota["reset"]>(
          "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits",
          token,
        ),
      ]);
      return quota ? { quota, reset } : null;
    },
    format(quota: CodexQuota, theme: Theme): string | null {
      const rateLimit = quota.quota?.rate_limit;
      if (!rateLimit) {
        return null;
      }

      const formatWindow = (window: CodexQuotaWindow | null | undefined): string | null =>
        window
          ? `${theme.fg("accent", `${window.used_percent}%`)}${theme.fg("dim", `/${formatRemaining(window.reset_at * 1000)}`)}`
          : null;

      const resetCount =
        quota.reset?.available_count ?? quota.quota?.rate_limit_reset_credits?.available_count;
      const resetExpiresAt = (quota.reset?.credits ?? [])
        .filter((credit) => credit.status === "available" && credit.expires_at)
        .map((credit) => Date.parse(credit.expires_at!))
        .filter((expiresAt): expiresAt is number => Number.isFinite(expiresAt))
        .sort((a, b) => a - b);

      return joinParts([
        formatWindow(rateLimit.primary_window),
        formatWindow(rateLimit.secondary_window),
        resetCount !== undefined
          ? [
              theme.fg("accent", `${resetCount}`),
              ...resetExpiresAt.map((expiresAt) => theme.fg("dim", formatRemaining(expiresAt))),
            ].join(theme.fg("dim", "/"))
          : null,
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
  xiaomi: createSource<XiaomiQuota, string>("xiaomi", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      // Manual cookie import
      // 1. Open `https://platform.xiaomimimo.com/#/console/balance`
      // 2. Copy a `Cookie:` header from your browser’s Network tab
      return process.env.XIAOMI_MIMO_COOKIE || null;
    },
    async fetch(cookie: string): Promise<XiaomiQuota | null> {
      // Ref: https://github.com/steipete/CodexBar/blob/ad33b32773bd6087cbb932ff60ae493008063cc4/Sources/CodexBarCore/Providers/MiMo/MiMoUsageFetcher.swift
      try {
        const resp = await fetch("https://platform.xiaomimimo.com/api/v1/balance", {
          signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
          headers: {
            Accept: "application/json, text/plain, */*",
            "Accept-Language": "en-US,en;q=0.9",
            Cookie: cookie,
            Origin: "https://platform.xiaomimimo.com",
            Referer: "https://platform.xiaomimimo.com/#/console/balance",
            "User-Agent":
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
            "x-timeZone": "UTC+01:00",
          },
        });
        if (!resp.ok) return null;
        const json = (await resp.json()) as XiaomiQuota;
        if (!json?.data || json.code !== 0) return null;
        return json;
      } catch {
        return null;
      }
    },
    format(quota: XiaomiQuota, theme: Theme): string | null {
      const { currency, balance } = quota.data!;
      const symbol = currency === "CNY" ? "¥" : "$";
      return theme.fg("accent", `${symbol}${formatDecimal(parseFloat(balance), 2)}`);
    },
  }),
  crofai: createSource("crofai", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.CROFAI_API_KEY || null;
    },
    async fetch(apiKey: string): Promise<CrofQuota | null> {
      return fetchJson<CrofQuota>("https://crof.ai/usage_api/", apiKey);
    },
    format(quota: CrofQuota, theme: Theme): string | null {
      return theme.fg("accent", `$${formatDecimal(quota.credits, 2)}`);
    },
  }),
  smartaipi: createSource("smartaipi", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.SMART_AIPI_TOKEN || null;
    },
    async fetch(token: string): Promise<SmartaipiQuota | null> {
      // https://www.npmjs.com/package/@smart-aipi/mcp
      return fetchJson<SmartaipiQuota>("https://smartaipi.com/api/usage", token);
    },
    format(quota: SmartaipiQuota, theme: Theme): string | null {
      return theme.fg("accent", `$${formatDecimal((quota.credits + quota.free_credits) / 100, 2)}`);
    },
  }),
  freemodel: createSource<FreemodelQuota, string>("freemodel", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return process.env.FREEMODEL_COOKIE || null;
    },
    async fetch(cookie: string): Promise<FreemodelQuota | null> {
      // Ref: https://github.com/zhezzma/freemodel-proxy/blob/30e40671127b6fd8538fac220246f7a309a8e0cc/src/usage.js#L64-L73
      try {
        const resp = await fetch("https://freemodel.dev/api/usage", {
          method: "GET",
          signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
          headers: {
            accept: "*/*",
            "cache-control": "no-cache",
            pragma: "no-cache",
            cookie,
            referer: "https://freemodel.dev/dashboard/usage",
          },
        });
        if (!resp.ok) return null;

        const json = (await resp.json()) as FreemodelQuota;
        return json?.window5h || json?.windowWeek ? json : null;
      } catch {
        return null;
      }
    },
    format(quota: FreemodelQuota, theme: Theme): string | null {
      const formatWindow = (w: FreemodelQuotaWindow | undefined): string | null => {
        if (!w) return null;

        const resetAt =
          typeof w.resetsAt === "number" && Number.isFinite(w.resetsAt)
            ? `/${formatRemaining(w.resetsAt * 1000)}`
            : "?";
        return `${theme.fg("accent", `$${formatDecimal(w.usedCents / 100, 2)}`)}${theme.fg("dim", `/$${formatDecimal(w.limitCents / 100, 2)}${resetAt}`)}`;
      };

      return joinParts([formatWindow(quota.window5h), formatWindow(quota.windowWeek)]);
    },
  }),
  firepass: createSource("firepass", {
    cacheTtlMs: IS_TERMUX ? 5 * MINUTE_MS : MINUTE_MS,
    async getAuth(): Promise<string | null> {
      return "-";
    },
    async fetch(_auth: string): Promise<FirepassUsage | null> {
      return await getDailyFirepassUsage();
    },
    format(data: FirepassUsage, theme: Theme): string | null {
      return joinParts(
        [
          theme.fg("accent", formatTokens(data.tokens)),
          data.cost > 0
            ? theme.fg(
                "dim",
                `$${formatDecimal(data.cost, data.cost < 0.01 ? 4 : data.cost < 1 ? 3 : 2)}`,
              )
            : null,
        ],
        theme.fg("dim", "/"),
      );
    },
  }),
  codebuddy: createSource<CodebuddyQuota, CodebuddyOAuthCredentials>("codebuddy", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<CodebuddyOAuthCredentials | null> {
      return await readAuth<CodebuddyOAuthCredentials>("codebuddy");
    },
    async fetch(auth): Promise<CodebuddyQuota | null> {
      if (!auth.enterpriseId) return null;

      try {
        // https://www.codebuddy.cn/profile/usage
        const resp = await fetch(
          "https://www.codebuddy.cn/billing/meter/get-enterprise-user-usage",
          {
            method: "POST",
            signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
            headers: {
              Authorization: `Bearer ${auth.access}`,
              "X-Enterprise-Id": auth.enterpriseId,
            },
            body: "{}",
          },
        );
        if (!resp.ok) return null;
        const json = (await resp.json()) as CodebuddyQuota;
        if (!json?.data || json.code !== 0) return null;
        return json;
      } catch {
        return null;
      }
    },
    format(quota: CodebuddyQuota, theme: Theme): string | null {
      const { credit, limitNum, cycleResetTime } = quota.data;
      return joinParts([
        `${theme.fg("accent", formatDecimal(credit, 2))}${theme.fg("dim", `/${formatDecimal(limitNum, 2)}`)}`,
        theme.fg("dim", formatRemaining(Date.parse(cycleResetTime.replace(" ", "T")))),
      ]);
    },
  }),
  kiro: createSource<KiroQuota, KiroOAuthCredentials>("kiro", {
    cacheTtlMs: MINUTE_MS,
    async getAuth(): Promise<KiroOAuthCredentials | null> {
      return await readAuth<KiroOAuthCredentials>("kiro");
    },
    async fetch(auth): Promise<KiroQuota | null> {
      try {
        const region = auth.region || "us-east-1";
        const resp = await fetch(`https://q.${region}.amazonaws.com/`, {
          method: "POST",
          signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
          headers: {
            "Content-Type": "application/x-amz-json-1.0",
            Authorization: `Bearer ${auth.access}`,
            "X-Amz-Target": "AmazonCodeWhispererService.GetUsageLimits",
          },
          body: JSON.stringify({ origin: "CLI", resourceType: "CREDIT" }),
        });
        if (!resp.ok) return null;
        return (await resp.json()) as KiroQuota;
      } catch {
        return null;
      }
    },
    format(quota: KiroQuota, theme: Theme): string | null {
      return joinParts(
        (quota.usageBreakdownList ?? []).map((b) => {
          const used = b.currentUsageWithPrecision ?? b.currentUsage;
          const limit = b.usageLimitWithPrecision ?? b.usageLimit;
          const resetAt = b.nextDateReset;
          return joinParts([
            `${theme.fg("accent", formatDecimal(used, 2))}${theme.fg("dim", `/${formatDecimal(limit, 2)}`)}`,
            resetAt
              ? theme.fg(
                  "dim",
                  formatRemaining(typeof resetAt === "number" ? resetAt * 1000 : resetAt),
                )
              : null,
          ]);
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
