/**
 * GitHub Copilot short-term rate-limit indicator.
 *
 * Copilot exposes its rolling 5h and weekly windows only on inference response
 * headers. We read them passively and show them in the footer.
 *
 * Normal responses go through `after_provider_response`. 429s still need a tiny
 * fetch wrapper because the OpenAI SDK throws before that hook runs.
 *
 * Header shapes:
 *   - 429: `retry-after` / `x-ratelimit-user-retry-after`, `x-ratelimit-exceeded`
 *   - usage: `x-usage-ratelimit-session` / `x-usage-ratelimit-weekly`
 *            `ent=0&rem=35.3&rst=2026-...`
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "copilot-ratelimit";
const PROVIDER = "github-copilot";
// Carries the pre-wrap fetch so /reload can unwrap back to the true base fetch.
const FETCH_MARKER = Symbol.for("copilot-ratelimit.fetch");
// The server only returns the rolling-window headers when the request carries
// `X-GitHub-Api-Version`. pi-ai sends it for /models and policy but NOT for
// inference, so without injecting it the indicator has nothing to read from
// normal responses. Keep in sync with pi's COPILOT_API_VERSION
// (utils/oauth/github-copilot.ts).
const COPILOT_API_VERSION = "2026-06-01";

interface MarkedFetch {
  [FETCH_MARKER]?: typeof fetch;
}

type HeaderSource = Headers | Record<string, string>;

interface WindowState {
  /** 0-100, percent of the window already consumed. */
  usedPercent: number;
  /** Absolute ms timestamp the window resets at, if reported. */
  resetsAt?: number;
}

// The render interval re-derives text from this state so countdowns tick
// without fresh responses.
type DisplayState =
  | { kind: "none" }
  | { kind: "blocked"; label: string } // 429 with no usable retry-after
  | { kind: "limited"; resetAt: number } // 429, ticking countdown
  | { kind: "usage"; windows: WindowState[] }; // 200, ≥50% usage

/** Parse a Copilot usage window header like `ent=0&rem=94.7&rst=2026-...`. */
function parseWindowHeader(raw: string | undefined): WindowState | undefined {
  if (!raw) return undefined;
  const params = new URLSearchParams(raw);
  const rem = params.get("rem");
  if (rem === null) return undefined;
  const remaining = Number(rem);
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

function getHeader(headers: HeaderSource, name: string): string | undefined {
  return headers instanceof Headers ? (headers.get(name) ?? undefined) : headers[name];
}

function retryResetAt(headers: HeaderSource): number | undefined {
  const seconds = Number(
    getHeader(headers, "retry-after") ?? getHeader(headers, "x-ratelimit-user-retry-after") ?? "0",
  );
  return Number.isFinite(seconds) && seconds > 0 ? Date.now() + seconds * 1000 : undefined;
}

function usageWindows(headers: HeaderSource): WindowState[] {
  const session = parseWindowHeader(getHeader(headers, "x-usage-ratelimit-session"));
  const weekly = parseWindowHeader(getHeader(headers, "x-usage-ratelimit-weekly"));
  return [session, weekly].filter((window): window is WindowState => window !== undefined);
}

type FetchInput = Parameters<typeof fetch>[0];

// Only inference endpoints carry the rate-limit window headers; other Copilot
// requests (e.g. GET /models) also have `x-copilot-service-request-id` but no
// window info, and must not be treated as a rate-limit update.
const COPILOT_INFERENCE_PATHS = ["/chat/completions", "/v1/messages", "/messages", "/responses"];

function isCopilotInference(input: FetchInput): boolean {
  let url: URL;
  try {
    url =
      typeof input === "string"
        ? new URL(input)
        : input instanceof URL
          ? input
          : new URL(input.url);
  } catch {
    return false;
  }
  if (!url.hostname.includes("githubcopilot.com")) return false;
  return COPILOT_INFERENCE_PATHS.some((p) => url.pathname.endsWith(p));
}

export default function (pi: ExtensionAPI) {
  pi.registerProvider(PROVIDER, {
    headers: { "X-GitHub-Api-Version": COPILOT_API_VERSION },
  });

  // Captured at session_start so the fetch wrapper can still render status.
  let currentCtx: ExtensionContext | undefined;

  let display: DisplayState = { kind: "none" };
  let renderTimer: ReturnType<typeof setInterval> | undefined;
  let installed = false;

  function setStatus(text: string | undefined): void {
    currentCtx?.ui.setStatus(STATUS_KEY, text);
  }

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

  function clearDisplay(): void {
    display = { kind: "none" };
    stopRenderTimer();
    setStatus(undefined);
  }

  function applyDisplay(next: DisplayState): void {
    display = next;
    render();
    if (next.kind === "limited" || next.kind === "usage") ensureRenderTimer();
    else stopRenderTimer();
  }

  function formatUsageStatus(window: WindowState, now: number): string {
    const base = accent(`${Math.round(window.usedPercent)}%`);
    if (!window.resetsAt || window.resetsAt <= now) return base;
    return `${base}${dim(`/${formatDuration(window.resetsAt - now)}`)}`;
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
        const parts = display.windows.map((window) => formatUsageStatus(window, now));
        setStatus(dim(" ") + parts.join(" "));
        return;
      }
    }
  }

  function applyRateLimitDisplay(headers: HeaderSource): void {
    const exceeded = getHeader(headers, "x-ratelimit-exceeded");
    const label = exceeded?.includes("weekly") ? "wk" : "5h";
    const resetAt = retryResetAt(headers);
    applyDisplay(resetAt ? { kind: "limited", resetAt } : { kind: "blocked", label });
  }

  function applyUsageDisplay(headers: HeaderSource): void {
    // Below ~50% usage the server omits these headers, so just hide the status.
    const windows = usageWindows(headers);
    applyDisplay(windows.length > 0 ? { kind: "usage", windows } : { kind: "none" });
  }

  function handleCopilotResponse(status: number, headers: HeaderSource): void {
    if (status === 429) return applyRateLimitDisplay(headers);
    applyUsageDisplay(headers);
  }

  function install429Sniffer(): void {
    // One install per module instance; /reload re-binds by recovering the true
    // underlying fetch from the previous wrapper's marker.
    if (installed) return;
    const marked = globalThis.fetch as unknown as MarkedFetch;
    const base = marked[FETCH_MARKER] ?? (globalThis.fetch as typeof fetch);

    const wrapped: typeof fetch = async (input, init) => {
      const inference = isCopilotInference(input);
      const response = await base(input, init);
      try {
        if (inference && response.status === 429)
          handleCopilotResponse(response.status, response.headers);
      } catch (error) {
        // A sniff failure must never break a real request, but surface it so
        // sniffer bugs aren't silently invisible.
        console.error("[copilot-ratelimit] sniff failed:", error);
      }
      return response;
    };
    (wrapped as unknown as MarkedFetch)[FETCH_MARKER] = base;
    installed = true;
    globalThis.fetch = wrapped;
  }

  // 429s are handled by the fetch wrapper below: in pi-ai's SDK path the request
  // throws before `onResponse` runs, so this event never fires on 429 in
  // practice — the guard just keeps the two paths from overlapping.
  pi.on("after_provider_response", (event, ctx) => {
    if (ctx.model?.provider !== PROVIDER || event.status === 429) return;
    handleCopilotResponse(event.status, event.headers);
  });

  pi.on("session_start", (_event, ctx) => {
    currentCtx = ctx;
    display = { kind: "none" };
    install429Sniffer();
  });

  pi.on("session_shutdown", () => {
    clearDisplay();
    currentCtx = undefined;
  });
}
