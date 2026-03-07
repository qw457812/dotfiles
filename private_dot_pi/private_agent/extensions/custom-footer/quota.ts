import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { TUI } from "@mariozechner/pi-tui";

const CACHE_DIR = join(homedir(), ".cache", "pi-agent-footer");
const COPILOT_APPS_PATH = join(
  homedir(),
  ".config",
  "github-copilot",
  "apps.json",
);
const PI_AGENT_AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;
const RETRY_COOLDOWN_MS = 30 * 1000;

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
  formatQuota: (quota: T) => string | null;
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
  return cache !== null && Date.now() - cache.updatedAt < ttlMs;
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
    return `${days}d${hours}h${minutes}m`;
  }
  if (hours > 0) {
    return `${hours}h${minutes}m`;
  }
  return `${minutes}m`;
}

function createCacheStore<T>(cacheKey: string): CacheStore<T> {
  const filePath = join(CACHE_DIR, `${cacheKey}.json`);

  return {
    async readFresh(ttlMs: number): Promise<CachedValue<T> | null> {
      const cached = await readJsonFile<CachedValue<T>>(filePath);
      return isCacheFresh(cached, ttlMs) ? cached : null;
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

class QuotaProvider<T> implements QuotaProviderRuntime {
  private readonly cacheStore: CacheStore<T>;
  private cache: CachedValue<T> | null = null;
  private fetching = false;
  private nextRetryAt = 0;

  constructor(private readonly spec: QuotaProviderSpec<T>) {
    this.cacheStore = createCacheStore<T>(spec.cacheKey);
  }

  getText(): string | null {
    if (!isCacheFresh(this.cache, this.spec.cacheTtlMs)) {
      return null;
    }

    return this.spec.formatQuota(this.cache.value);
  }

  async refresh(tui: TUI): Promise<void> {
    if (!this.shouldRefresh()) {
      return;
    }

    this.fetching = true;
    try {
      const cache = await this.resolveQuota();
      if (!cache) {
        return;
      }

      this.updateCache(cache);
      tui.requestRender();
    } finally {
      this.fetching = false;
    }
  }

  private shouldRefresh(): boolean {
    return (
      !isCacheFresh(this.cache, this.spec.cacheTtlMs) &&
      !this.fetching &&
      Date.now() >= this.nextRetryAt
    );
  }

  private updateCache(cache: CachedValue<T>): void {
    this.cache = cache;
    this.nextRetryAt = 0;
  }

  private scheduleRetry(): void {
    this.nextRetryAt = Date.now() + this.spec.retryCooldownMs;
  }

  private failRefresh(): null {
    this.scheduleRetry();
    return null;
  }

  private async resolveQuota(): Promise<CachedValue<T> | null> {
    return (
      (await this.cacheStore.readFresh(this.spec.cacheTtlMs)) ??
      (await this.fetchQuota())
    );
  }

  private async fetchQuota(): Promise<CachedValue<T> | null> {
    const auth = await this.spec.readAuth();
    if (!auth) {
      return this.failRefresh();
    }

    const quota = await this.spec.fetchQuota(auth);
    if (!quota) {
      return this.failRefresh();
    }

    const cached = createCachedValue(quota);

    try {
      await this.cacheStore.write(quota);
    } catch {
      // Keep the in-memory value even if the disk cache cannot be updated.
    }

    return cached;
  }
}

const QUOTA_PROVIDERS: Record<string, QuotaProviderRuntime> = {
  synthetic: new QuotaProvider({
    cacheKey: "synthetic-quota",
    cacheTtlMs: MINUTE_MS,
    retryCooldownMs: RETRY_COOLDOWN_MS,
    async readAuth(): Promise<string | null> {
      return process.env.SYNTHETIC_API_KEY || null;
    },
    async fetchQuota(apiKey: string): Promise<SyntheticQuota | null> {
      return fetchJson<SyntheticQuota>(
        "https://api.synthetic.new/v2/quotas",
        apiKey,
      );
    },
    formatQuota(quota: SyntheticQuota): string {
      return [
        `${quota.subscription.requests}/${quota.subscription.limit} ${formatTimeRemaining(quota.subscription.renewsAt)}`,
        `${quota.freeToolCalls.requests}/${quota.freeToolCalls.limit} ${formatTimeRemaining(quota.freeToolCalls.renewsAt)}`,
      ].join(" ");
    },
  }),
  "github-copilot": new QuotaProvider({
    cacheKey: "github-copilot-quota",
    cacheTtlMs: 3 * MINUTE_MS,
    retryCooldownMs: RETRY_COOLDOWN_MS,
    async readAuth(): Promise<string | null> {
      // curl -s "https://api.github.com/copilot_internal/user" -H "Authorization: Bearer $(jq -r '.[] | select(.oauth_token) | .oauth_token' ~/.config/github-copilot/apps.json | head -1)"
      const apps =
        await readJsonFile<Record<string, { oauth_token?: string }>>(
          COPILOT_APPS_PATH,
        );
      if (!apps) {
        return null;
      }

      const app = Object.values(apps).find(({ oauth_token }) => oauth_token);
      return app?.oauth_token || null;
    },
    async fetchQuota(token: string): Promise<CopilotQuota | null> {
      return fetchJson<CopilotQuota>(
        "https://api.github.com/copilot_internal/user",
        token,
      );
    },
    formatQuota(quota: CopilotQuota): string {
      const premium = quota.quota_snapshots.premium_interactions;
      return `${premium.entitlement - premium.remaining}/${premium.entitlement} ${formatTimeRemaining(quota.quota_reset_date_utc)}`;
    },
  }),
  "openai-codex": new QuotaProvider({
    cacheKey: "openai-codex-quota",
    cacheTtlMs: MINUTE_MS,
    retryCooldownMs: RETRY_COOLDOWN_MS,
    async readAuth(): Promise<string | null> {
      // curl -s -H "Authorization: Bearer $(cat ~/.codex/auth.json | jq -r '.tokens.access_token')" "https://chatgpt.com/backend-api/wham/usage" | jq .
      const auth =
        await readJsonFile<Record<string, { access?: string }>>(
          PI_AGENT_AUTH_PATH,
        );
      return auth?.["openai-codex"]?.access || null;
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

      const primary = rateLimit.primary_window;
      const secondary = rateLimit.secondary_window;
      const parts: string[] = [];
      if (primary) {
        parts.push(
          `${primary.used_percent}% ${formatTimeRemaining(primary.reset_at * 1000)}`,
        );
      }
      if (secondary) {
        parts.push(
          `${secondary.used_percent}% ${formatTimeRemaining(secondary.reset_at * 1000)}`,
        );
      }
      return parts.length > 0 ? parts.join(" ") : null;
    },
  }),
};

export function getQuotaText(
  provider: string | undefined,
  tui: TUI,
): string | null {
  const quotaProvider = provider ? QUOTA_PROVIDERS[provider] : null;
  if (!quotaProvider) {
    return null;
  }

  const quotaText = quotaProvider.getText();
  void quotaProvider.refresh(tui);
  return quotaText;
}
