/**
 * Websearch selection layer — mirrors OpenCode v2's packages/core/src/websearch.ts
 * (interactive provider selection, random routing with per-session affinity,
 * 429 cooldowns and failover), reduced to pi-extension scope:
 *
 * Selection model:
 *   PI_WEBSEARCH_PROVIDER = exa | parallel | firecrawl | tavily | random (default)
 *
 * - Forced selection (env names a specific provider): single attempt, errors
 *   (including 429) surface directly. Mirrors v2's non-random path, which
 *   never consults cooldowns.
 * - Random selection (default): each session sticks to one provider (affinity)
 *   until that provider is rate limited; HTTP 429 puts it on a cooldown sized
 *   by Retry-After (seconds or HTTP-date, fallback 60s) and the query fails
 *   over to another available provider.
 *
 * Session-scoped persistence (pi-native, exceeds v2): stickiness is restored on
 * session_start from a "websearch.selection" custom session entry, so
 * `pi --resume` keeps the same provider; affinity changes are re-appended so
 * the resumed session follows failovers too.
 *
 * Differences from v2: no KV (no global persistence, env is the config),
 * no consent flow, no app.integration connections — env vars hold credentials.
 */

import {
  HttpCallError,
  PROVIDER_IDS,
  type ProviderID,
  type WebSearchProvider,
  type WebSearchResult,
} from "./providers/types";

export type Selection = ProviderID | "random";

/** customType of the session entry persisting per-session provider affinity. */
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
  /** How many providers were attempted (1 unless failover happened). */
  attempts: number;
}

export interface WebSearchService {
  query(input: { query: string }, options: WebSearchQueryOptions): Promise<WebSearchQueryResult>;
  /** Restore per-session provider affinity (e.g. from a session entry). */
  restoreAffinity(sessionID: string, provider: ProviderID): void;
  forgetSession(sessionID: string): void;
}

// ---------------------------------------------------------------------------
// Env selection
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Cooldown parsing (v2's cooldownMillis, verbatim semantics)
// ---------------------------------------------------------------------------

function cooldownMillis(value: string | undefined, now: number): number {
  if (!value?.trim()) return COOLDOWN_FALLBACK_MS;
  const seconds = Number(value);
  if (Number.isFinite(seconds)) return seconds >= 0 ? seconds * 1000 : COOLDOWN_FALLBACK_MS;
  const date = Date.parse(value);
  return Number.isFinite(date) ? Math.max(0, date - now) : COOLDOWN_FALLBACK_MS;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

export function createWebSearchService(providers: WebSearchProvider[]): WebSearchService {
  const registry = new Map<ProviderID, WebSearchProvider>(providers.map((p) => [p.id, p]));

  /** Per-session affinity ({provider}) for random mode. In-memory only. */
  const preferred = new Map<string, { provider?: ProviderID }>();

  /** HTTP 429 cooldowns, pruned when expired (mirrors v2). */
  const cooldowns = new Map<ProviderID, { until: number; error: HttpCallError }>();

  /**
   * Random-routing candidates: providers whose required API key env is set
   * (when declared). Keyless-unusable providers (Tavily without a key) are
   * excluded so random picks never wedge a session on a failing provider;
   * forced PI_WEBSEARCH_PROVIDER selection bypasses this filter.
   */
  function isRandomCandidate(provider: WebSearchProvider): boolean {
    return !provider.requiresApiKey || Boolean(process.env[provider.requiresApiKey]);
  }

  function randomProvider(
    now: number,
    affinity: { provider?: ProviderID },
    attempted?: Set<ProviderID>,
  ): WebSearchProvider | undefined {
    for (const [id, cooldown] of cooldowns) {
      if (cooldown.until <= now || !registry.has(id)) cooldowns.delete(id);
    }
    const current = affinity.provider !== undefined ? registry.get(affinity.provider) : undefined;
    if (
      current &&
      isRandomCandidate(current) &&
      !cooldowns.has(current.id) &&
      !attempted?.has(current.id)
    ) {
      return current;
    }
    const available = providers.filter(
      (p) => isRandomCandidate(p) && !cooldowns.has(p.id) && !attempted?.has(p.id),
    );
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

    // Forced selection: single attempt, cooldowns ignored (v2 semantics).
    if (choice !== "random") {
      const provider = registry.get(choice);
      if (!provider) throw new Error(`Unknown websearch provider: ${choice}`);
      options.onProvider?.(provider.id, 1);
      const results = await provider.execute(input, { signal: options.signal });
      return { provider: provider.id, results, attempts: 1 };
    }

    // Random selection: sticky affinity, 429 cooldown, failover.
    const affinity = preferred.get(options.sessionID) ?? {};
    preferred.set(options.sessionID, affinity);
    const initialPrevious = affinity.provider;
    let provider = randomProvider(Date.now(), affinity);
    if (!provider) {
      throw new Error(
        "No available websearch provider (all cooling down after rate limits or missing API keys)",
      );
    }
    // Only notify when the pick actually changed the affinity (initial pick,
    // not a restored/sticky hit — avoids duplicate session entries).
    notifyAffinity(options, affinity, initialPrevious);

    const attempted = new Set<ProviderID>();
    let cooldownError: HttpCallError | undefined;
    while (true) {
      options.onProvider?.(provider.id, attempted.size + 1);
      // v2 semantics: `cooldown` is a let — set either by the 429 handler
      // below or read from the map when skipping an actively cooled provider.
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
