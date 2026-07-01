/**
 * GitHub Copilot short-term rate-limit indicator.
 *
 * Copilot enforces two rolling windows on top of the monthly quota:
 *   - session: `global-usage-5-hour-key` (rolling 5 hours)
 *   - weekly:  `global-usage-weekly-key` (every Monday 00:00 UTC)
 *
 * There is no read-only endpoint for these. The window state rides along on
 * every inference response's headers, so we read it passively — zero extra
 * requests, zero quota spent.
 *
 * We cannot use pi's `after_provider_response` event: it fires from `onResponse`,
 * which pi-ai calls AFTER `await client.create()` returns, and the OpenAI SDK
 * throws an APIError on 429 before that line — so the event never fires exactly
 * when we need it (when rate-limited). Instead we wrap `globalThis.fetch` and read
 * the raw response headers before the SDK sees them. Same technique the neuralwatt
 * extension uses to inspect responses.
 *
 * Ref:
 * - pi-ai onResponse placement: packages/ai/dist/api/openai-completions.js (~L114-118)
 * - neuralwatt fetch wrap: github.com/monotykamary/pi-neuralwatt-provider index.ts
 * - window/header format: github.com/DrSmile444/copilot-status-mcp
 *
 * Headers (lowercased):
 *   429: retry-after / x-ratelimit-user-retry-after  (seconds until reset)
 *        x-ratelimit-exceeded  (e.g. "...:global-usage-5-hour-key:...")
 *   200: x-usage-ratelimit-session / x-usage-ratelimit-weekly
 *        "ent=0&rem=35.3&rst=2026-..."  (rem = remaining %, rst = reset ISO time)
 *        Only present once usage crosses ~50%; below that the server omits them.
 *
 * Displayed via ctx.ui.setStatus() — appears in the footer's extension-status line.
 * Format is `<percent>/<time>` pairs; percents are accented, the `/`
 * separator and the time value are dimmed. Rate-limited windows show 100%; the
 * blocked fallback shows the window label in place of a countdown.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "copilot-ratelimit";
// Marker stored on our wrapper carrying the pre-wrap original fetch. A
// re-loaded module instance reads this to recover the true underlying fetch
// from the previous instance's wrapper, so /reload re-binds to the new
// closures instead of leaving the stale ones driving the status.
const FETCH_MARKER = Symbol.for("copilot-ratelimit.fetch");
// Copilot only returns the rate-limit window headers when the request carries
// `X-GitHub-Api-Version`. pi's inference paths (anthropic + openai) omit it — it's
// only sent for /models and policy — so the sniffer injects pi's own version.
const COPILOT_API_VERSION = "2026-06-01";

interface MarkedFetch {
  [FETCH_MARKER]?: typeof fetch;
}

interface WindowState {
  /** 0-100, percent of the window already consumed. */
  usedPercent: number;
  /** Absolute ms timestamp the window resets at, if reported. */
  resetsAt?: number;
}

interface WindowView {
  label: string;
  usedPercent: number;
  resetsAt?: number;
}

// Current display state. The single render interval re-derives the status text
// from this, so countdowns tick without a fresh response.
type DisplayState =
  | { kind: "none" }
  | { kind: "blocked"; label: string } // 429 with no usable retry-after
  | { kind: "limited"; label: string; resetAt: number } // 429, ticking countdown
  | { kind: "usage"; windows: WindowView[] }; // 200, ≥50% usage

// States whose text changes over time and so need the render interval running.
const TICKING: ReadonlySet<DisplayState["kind"]> = new Set(["limited", "usage"]);

/**
 * Parse a Copilot window header.
 *
 * Format: `key=value` pairs joined by `&` (e.g. `ent=0&rem=35.3&rst=2026-...`).
 * Split manually rather than via URLSearchParams so both `&` and `;` are tolerated;
 * header values never contain either separator, so this is safe.
 */
function parseWindowHeader(raw: string | undefined): WindowState | undefined {
  if (!raw) return undefined;
  const params = new Map<string, string>();
  for (const part of raw.split(/[;&]/)) {
    const eq = part.indexOf("=");
    if (eq < 0) continue;
    const key = part.slice(0, eq).trim();
    if (!key) continue;
    // Values are URL-encoded (e.g. `rst=2026-...T17%3A05%3A31Z`); decode so timestamps parse.
    let value = part.slice(eq + 1).trim();
    try {
      value = decodeURIComponent(value);
    } catch {
      // Leave as-is on malformed sequences.
    }
    params.set(key, value);
  }
  const remaining = Number(params.get("rem"));
  if (!Number.isFinite(remaining)) return undefined;
  const rst = params.get("rst");
  const resetsAt = rst ? Date.parse(rst) : NaN;
  return {
    usedPercent: Math.max(0, Math.min(100, 100 - remaining)),
    resetsAt: Number.isFinite(resetsAt) ? resetsAt : undefined,
  };
}

function formatDuration(ms: number): string {
  if (ms <= 0) return "0s";
  const totalSeconds = Math.floor(ms / 1000);
  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (days > 0) return `${days}d${hours > 0 ? hours + "h" : ""}`;
  if (hours > 0) return `${hours}h${minutes > 0 ? minutes + "m" : ""}`;
  if (minutes > 0) return `${minutes}m`;
  return `${seconds}s`;
}

/** Map an `x-ratelimit-exceeded` value to a short window label. */
function windowLabel(exceeded: string | undefined): "5h" | "wk" {
  return exceeded?.includes("weekly") ? "wk" : "5h";
}

type FetchInput = Parameters<typeof fetch>[0];

function extractUrl(input: FetchInput): string {
  if (typeof input === "string") return input;
  if (input instanceof URL) return input.href;
  return input.url;
}

// Only inference endpoints carry the rate-limit window headers; other Copilot
// requests (e.g. GET /models) also have `x-copilot-service-request-id` but no
// window info, and must not be treated as a rate-limit update.
const COPILOT_INFERENCE_PATHS = ["/chat/completions", "/v1/messages", "/messages", "/responses"];

function isCopilotInference(input: FetchInput): boolean {
  let url: URL;
  try {
    url = new URL(extractUrl(input));
  } catch {
    return false;
  }
  if (!url.hostname.includes("githubcopilot.com")) return false;
  return COPILOT_INFERENCE_PATHS.some((p) => url.pathname.endsWith(p));
}

/** Ensure a Copilot request carries `X-GitHub-Api-Version` so the server returns window headers. */
function withCopilotApiVersion(init?: RequestInit): RequestInit {
  const headers = new Headers(init?.headers);
  if (!headers.has("x-github-api-version")) {
    headers.set("x-github-api-version", COPILOT_API_VERSION);
  }
  return { ...init, headers };
}

// The rate-limit headers we care about, plus the marker that identifies a
// Copilot inference response (`x-copilot-service-request-id`).
const HEADER_PROBES = [
  "x-copilot-service-request-id",
  "retry-after",
  "x-ratelimit-user-retry-after",
  "x-ratelimit-exceeded",
  "x-usage-ratelimit-session",
  "x-usage-ratelimit-weekly",
] as const;

export default function (pi: ExtensionAPI) {
  // Captured at session_start so the fetch wrapper (which has no ctx) can reach
  // the UI and theme (for coloring the status text).
  let currentCtx: ExtensionContext | undefined;

  let display: DisplayState = { kind: "none" };
  let renderTimer: ReturnType<typeof setInterval> | undefined;
  // True underlying fetch captured on first install; doubles as the
  // "installed by this instance" flag so we don't re-wrap per session_start.
  let originalFetch: typeof fetch | undefined;

  function setStatus(text: string | undefined): void {
    currentCtx?.ui.setStatus(STATUS_KEY, text);
  }

  // Color helpers read the live theme from currentCtx (ExtensionUIContext.theme).
  const dim = (text: string): string => currentCtx?.ui.theme.fg("dim", text) ?? text;
  const accent = (text: string): string => currentCtx?.ui.theme.fg("accent", text) ?? text;

  function stopRenderTimer(): void {
    if (renderTimer) {
      clearInterval(renderTimer);
      renderTimer = undefined;
    }
  }

  function ensureRenderTimer(): void {
    if (!renderTimer) renderTimer = setInterval(render, 15_000);
  }

  // Clear to the empty state: drop status text and stop the ticking interval.
  function clearDisplay(): void {
    display = { kind: "none" };
    stopRenderTimer();
    setStatus(undefined);
  }

  // Render the current state, then keep the interval alive only for states
  // that change over time (limited/usage); the rest are static.
  function applyDisplay(next: DisplayState): void {
    display = next;
    render();
    if (TICKING.has(next.kind)) ensureRenderTimer();
    else stopRenderTimer();
  }

  function render(): void {
    switch (display.kind) {
      case "none":
        setStatus(undefined);
        return;
      case "blocked":
        // No usable retry-after: fully consumed, show the window label in place of a countdown.
        setStatus(dim(" ") + accent("100%") + dim(`/${display.label}`));
        return;
      case "limited": {
        const remaining = display.resetAt - Date.now();
        // Window has rolled past — hide the status rather than show a stale "ok".
        if (remaining <= 0) return clearDisplay();
        setStatus(dim(" ") + accent("100%") + dim(`/${formatDuration(remaining)}`));
        return;
      }
      case "usage": {
        const now = Date.now();
        const parts = display.windows.map((w) => {
          const base = accent(`${Math.round(w.usedPercent)}%`);
          return w.resetsAt && w.resetsAt > now
            ? `${base}${dim(`/${formatDuration(w.resetsAt - now)}`)}`
            : base;
        });
        setStatus(dim(" ") + parts.join(" "));
        return;
      }
    }
  }

  function handleCopilotResponse(status: number, headers: Record<string, string>): void {
    if (status === 429) {
      const seconds = Number(
        headers["retry-after"] ?? headers["x-ratelimit-user-retry-after"] ?? "0",
      );
      const label = windowLabel(headers["x-ratelimit-exceeded"]);
      const resetAt =
        Number.isFinite(seconds) && seconds > 0 ? Date.now() + seconds * 1000 : undefined;
      applyDisplay(resetAt ? { kind: "limited", label, resetAt } : { kind: "blocked", label });
      return;
    }

    // 200 (or other non-429): windows are only reported above ~50% usage. When no
    // window header is returned (usage below ~50%), the server conveys no info, so
    // hide the status rather than claim "ok".
    const session = parseWindowHeader(headers["x-usage-ratelimit-session"]);
    const weekly = parseWindowHeader(headers["x-usage-ratelimit-weekly"]);
    const windows: WindowView[] = [];
    if (session)
      windows.push({ label: "5h", usedPercent: session.usedPercent, resetsAt: session.resetsAt });
    if (weekly)
      windows.push({ label: "wk", usedPercent: weekly.usedPercent, resetsAt: weekly.resetsAt });
    applyDisplay(windows.length > 0 ? { kind: "usage", windows } : { kind: "none" });
  }

  function installFetchSniffer(): void {
    // Already installed by THIS module instance. The wrapper closures read live
    // module state (currentCtx/display), so one install serves every session in
    // this instance — no re-wrap needed across session_start events.
    if (originalFetch) return;

    // A previous instance (e.g. after /reload) may have left its wrapper on
    // globalThis.fetch. Recover the true underlying fetch from it so we never
    // stack wrappers and always bind the current closures.
    const marked = globalThis.fetch as unknown as MarkedFetch;
    const base = marked[FETCH_MARKER] ?? (globalThis.fetch as typeof fetch);

    const wrapped: typeof fetch = async (input, init) => {
      const inference = isCopilotInference(input);
      // Inject X-GitHub-Api-Version so the server returns the rate-limit window headers.
      const response = await base(input, inference ? withCopilotApiVersion(init) : init);
      try {
        if (!inference) return response;

        const headers: Record<string, string> = {};
        for (const name of HEADER_PROBES) {
          const value = response.headers.get(name);
          if (value) headers[name] = value;
        }
        // `x-copilot-service-request-id` reliably marks Copilot responses (429 included).
        if (headers["x-copilot-service-request-id"]) {
          handleCopilotResponse(response.status, headers);
        }
      } catch (error) {
        // A sniff failure must never break a real request, but surface it so
        // sniffer bugs aren't silently invisible.
        console.error("[copilot-ratelimit] sniff failed:", error);
      }
      return response;
    };
    (wrapped as unknown as MarkedFetch)[FETCH_MARKER] = base;
    originalFetch = base;
    globalThis.fetch = wrapped;
  }

  pi.on("session_start", (_event, ctx) => {
    currentCtx = ctx;
    display = { kind: "none" };
    installFetchSniffer();
  });

  pi.on("session_shutdown", () => {
    clearDisplay();
    currentCtx = undefined;
  });
}
