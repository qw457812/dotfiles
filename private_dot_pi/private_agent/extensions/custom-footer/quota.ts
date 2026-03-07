import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { TUI } from "@mariozechner/pi-tui";

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

export function getQuotaText(
  provider: string | undefined,
  tui: TUI,
): string | null {
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
