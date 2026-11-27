// Mirrors the pinned OpenCode selection logic; see README.md for Pi's configuration.

import {
  HttpCallError,
  PROVIDER_IDS,
  type ProviderID,
  type WebSearchProvider,
  type WebSearchResult,
} from "./providers/types";

export type Selection = ProviderID | "random";

export const SELECTION_ENTRY_TYPE = "websearch.selection";

const COOLDOWN_FALLBACK_MS = 60_000;

export interface WebSearchQueryOptions {
  sessionID: string;
  signal?: AbortSignal;
  /** Progress callback: (provider, attempt number starting at 1). */
  onProvider?: (provider: ProviderID, attempt: number) => void;
  /** Invoked whenever random affinity changes (initial pick or failover). */
  onAffinityChange?: (provider: ProviderID) => void;
}

export interface WebSearchQueryResult {
  provider: ProviderID;
  results: WebSearchResult[];
  attempts: number;
}

export interface WebSearchService {
  query(input: { query: string }, options: WebSearchQueryOptions): Promise<WebSearchQueryResult>;
  /** Restore per-session provider affinity (e.g. from a session entry). */
  restoreAffinity(sessionID: string, provider: ProviderID): void;
  forgetSession(sessionID: string): void;
}

let cachedSelection: Selection | undefined;

export function getSelection(): Selection {
  cachedSelection ??= readEnvSelection();
  return cachedSelection;
}

function readEnvSelection(): Selection {
  const raw = process.env.PI_WEBSEARCH_PROVIDER?.trim().toLowerCase();
  if (!raw || raw === "random") return "random";
  if ((PROVIDER_IDS as readonly string[]).includes(raw)) return raw as ProviderID;
  console.warn(
    `[websearch] Ignoring invalid PI_WEBSEARCH_PROVIDER=${raw} (valid: ${[...PROVIDER_IDS, "random"].join(", ")})`,
  );
  return "random";
}

/** The provider forced via env, or undefined for random routing. */
export function forcedSelection(): ProviderID | undefined {
  const selection = getSelection();
  return selection === "random" ? undefined : selection;
}

function cooldownMillis(value: string | undefined, now: number): number {
  if (!value?.trim()) return COOLDOWN_FALLBACK_MS;
  const seconds = Number(value);
  if (Number.isFinite(seconds)) return seconds >= 0 ? seconds * 1000 : COOLDOWN_FALLBACK_MS;
  const date = Date.parse(value);
  return Number.isFinite(date) ? Math.max(0, date - now) : COOLDOWN_FALLBACK_MS;
}

export function createWebSearchService(providers: WebSearchProvider[]): WebSearchService {
  const registry = new Map<ProviderID, WebSearchProvider>(providers.map((p) => [p.id, p]));

  const preferred = new Map<string, { provider?: ProviderID }>();

  const cooldowns = new Map<ProviderID, { until: number; error: HttpCallError }>();

  function randomProvider(
    now: number,
    affinity: { provider?: ProviderID },
    attempted?: Set<ProviderID>,
  ): WebSearchProvider | undefined {
    for (const [id, cooldown] of cooldowns) {
      if (cooldown.until <= now || !registry.has(id)) cooldowns.delete(id);
    }
    const current = affinity.provider !== undefined ? registry.get(affinity.provider) : undefined;
    if (current && !cooldowns.has(current.id) && !attempted?.has(current.id)) return current;
    const available = providers.filter((p) => !cooldowns.has(p.id) && !attempted?.has(p.id));
    const provider = available[Math.floor(Math.random() * available.length)];
    if (provider) affinity.provider = provider.id;
    return provider;
  }

  function notifyAffinity(
    options: WebSearchQueryOptions,
    affinity: { provider?: ProviderID },
    previous: ProviderID | undefined,
  ): void {
    if (affinity.provider !== undefined && affinity.provider !== previous) {
      options.onAffinityChange?.(affinity.provider);
    }
  }

  async function query(
    input: { query: string },
    options: WebSearchQueryOptions,
  ): Promise<WebSearchQueryResult> {
    const choice = getSelection();

    if (choice !== "random") {
      const provider = registry.get(choice);
      if (!provider) throw new Error(`Unknown websearch provider: ${choice}`);
      options.onProvider?.(provider.id, 1);
      const results = await provider.execute(input, { signal: options.signal });
      return { provider: provider.id, results, attempts: 1 };
    }

    const affinity = preferred.get(options.sessionID) ?? {};
    preferred.set(options.sessionID, affinity);
    const initialPrevious = affinity.provider;
    let provider = randomProvider(Date.now(), affinity);
    if (!provider) {
      // Preserve the rate-limit error even when this query starts during a cooldown.
      const cooling = cooldowns.values().next().value;
      if (cooling) throw cooling.error;
      throw new Error("No websearch provider available");
    }
    // Notify only when affinity changes so resume does not duplicate session entries.
    notifyAffinity(options, affinity, initialPrevious);

    const attempted = new Set<ProviderID>();
    let cooldownError: HttpCallError | undefined;
    while (true) {
      options.onProvider?.(provider.id, attempted.size + 1);
      let cooldown = cooldowns.get(provider.id);
      if (!cooldown || cooldown.until <= Date.now()) {
        attempted.add(provider.id);
        try {
          const results = await provider.execute(input, { signal: options.signal });
          return { provider: provider.id, results, attempts: attempted.size };
        } catch (err) {
          if (err instanceof HttpCallError && err.status === 429) {
            const now = Date.now();
            cooldown = { until: now + cooldownMillis(err.retryAfter, now), error: err };
            cooldowns.set(provider.id, cooldown);
          } else {
            throw err;
          }
        }
      }
      if (cooldown) cooldownError = cooldown.error;
      const previousAffinity = affinity.provider;
      const next = randomProvider(Date.now(), affinity, attempted);
      if (!next) throw cooldownError ?? new Error("No websearch provider available");
      provider = next;
      notifyAffinity(options, affinity, previousAffinity);
    }
  }

  function restoreAffinity(sessionID: string, provider: ProviderID): void {
    if (!registry.has(provider)) return;
    preferred.set(sessionID, { provider });
  }

  function forgetSession(sessionID: string): void {
    preferred.delete(sessionID);
  }

  return { query, restoreAffinity, forgetSession };
}
