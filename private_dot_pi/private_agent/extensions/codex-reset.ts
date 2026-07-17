/**
 * Codex banked rate-limit reset helper.
 *
 * Commands:
 *   /codex-reset                               Show banked reset credits and current usage.
 *   /codex-reset status                        Same as /codex-reset.
 *   /codex-reset consume                       Consume one available reset credit after confirmation.
 *   /codex-reset consume --dry-run             Preview the credit that would be consumed.
 *   /codex-reset consume --credit <id-prefix>  Consume a specific available credit.
 *   /codex-reset help                          Show command help.
 *
 * This uses the same private WHAM endpoints displayed in
 * custom-footer/quota.ts for Codex reset-credit status.
 *
 * Ref: https://github.com/aaamosh/codex-reset
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";
import { randomUUID } from "node:crypto";

const PROVIDER = "openai-codex";
const BASE_URL = "https://chatgpt.com/backend-api";
const FETCH_TIMEOUT_MS = 30_000;
const JWT_CLAIM_PATH = "https://api.openai.com/auth";

interface CodexAuth {
  token: string;
  accountId: string;
}

interface ResetCredit {
  id?: string;
  status?: string;
  reset_type?: string;
  granted_at?: string | null;
  expires_at?: string | null;
  title?: string | null;
}

interface ResetCreditsResponse {
  available_count?: number;
  credits?: ResetCredit[] | null;
}

interface UsageWindow {
  used_percent?: number;
  reset_at?: number;
  reset_after_seconds?: number;
  limit_window_seconds?: number;
}

interface UsageResponse {
  rate_limit?: {
    primary_window?: UsageWindow | null;
    secondary_window?: UsageWindow | null;
  } | null;
}

interface ConsumeResponse {
  code?: string;
  windows_reset?: number;
  credit?: {
    redeemed_at?: string | null;
  } | null;
}

interface Args {
  command: "status" | "consume" | "help";
  dryRun: boolean;
  creditId?: string;
}

class CodexResetError extends Error {
  constructor(
    message: string,
    readonly status?: number,
    readonly body?: unknown,
  ) {
    super(message);
  }
}

function parseArgs(raw: string, defaultCommand: Args["command"] = "status"): Args {
  const tokens = raw.trim().split(/\s+/).filter(Boolean);
  let command = defaultCommand;
  let start = 0;
  if (tokens[0] === "status" || tokens[0] === "consume" || tokens[0] === "help") {
    command = tokens[0];
    start = 1;
  }

  const args: Args = { command, dryRun: false };
  for (let i = start; i < tokens.length; i += 1) {
    const token = tokens[i];
    if (token === "--dry-run") {
      args.dryRun = true;
    } else if (token === "--credit" || token === "--credit-id") {
      args.creditId = tokens[++i];
    } else if (token.startsWith("--credit=")) {
      args.creditId = token.slice("--credit=".length);
    } else if (command === "consume" && !token.startsWith("-") && !args.creditId) {
      args.creditId = token;
    }
  }
  return args;
}

function decodeJwtPayload(token: string): Record<string, any> | null {
  const payload = token.split(".")[1];
  if (!payload) return null;

  try {
    const normalized = payload.replaceAll("-", "+").replaceAll("_", "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
  } catch {
    return null;
  }
}

function extractAccountId(token: string): string | null {
  const auth = decodeJwtPayload(token)?.[JWT_CLAIM_PATH];
  return typeof auth?.chatgpt_account_id === "string" ? auth.chatgpt_account_id : null;
}

async function loadAuth(ctx: ExtensionCommandContext): Promise<CodexAuth> {
  const token = await ctx.modelRegistry.getApiKeyForProvider(PROVIDER);
  if (!token) {
    throw new CodexResetError(`No ${PROVIDER} auth found. Run /login first.`);
  }

  const accountId = extractAccountId(token);
  if (!accountId) {
    throw new CodexResetError("Could not parse ChatGPT account id from the openai-codex token.");
  }

  return { token, accountId };
}

async function requestJson<T>(
  auth: CodexAuth,
  method: "GET" | "POST",
  path: string,
  body?: unknown,
): Promise<T> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${auth.token}`,
    "ChatGPT-Account-Id": auth.accountId,
    originator: "pi",
    "User-Agent": "pi-codex-reset",
  };
  const init: RequestInit = {
    method,
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    headers,
  };
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    init.body = JSON.stringify(body);
  }

  let resp: Response;
  try {
    resp = await fetch(`${BASE_URL}${path}`, init);
  } catch (error) {
    throw new CodexResetError(error instanceof Error ? error.message : String(error));
  }

  const text = await resp.text();
  let payload: unknown = text;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch {
    // Keep the raw body for the error summary.
  }

  if (!resp.ok) {
    throw new CodexResetError(`${method} ${path} failed`, resp.status, payload);
  }
  return payload as T;
}

function formatDuration(ms: number): string {
  if (ms <= 0) return "0s";
  const totalSeconds = Math.floor(ms / 1000);
  const days = Math.floor(totalSeconds / 86_400);
  const hours = Math.floor((totalSeconds % 86_400) / 3_600);
  const minutes = Math.floor((totalSeconds % 3_600) / 60);
  const seconds = totalSeconds % 60;
  if (days > 0) return `${days}d${hours > 0 ? hours + "h" : ""}`;
  if (hours > 0) return `${hours}h${minutes > 0 ? minutes + "m" : ""}`;
  if (minutes > 0) return `${minutes}m`;
  return `${seconds}s`;
}

function formatDate(date: string | null | undefined): string {
  if (!date) return "?";
  const time = Date.parse(date);
  if (!Number.isFinite(time)) return date;
  return `${new Date(time).toLocaleString()} (${formatDuration(time - Date.now())})`;
}

function formatWindow(window: UsageWindow | null | undefined): string {
  if (!window) return "n/a";

  const parts: string[] = [];
  if (typeof window.used_percent === "number") {
    parts.push(`${Math.round(window.used_percent)}% used`);
  }
  if (typeof window.limit_window_seconds === "number") {
    parts.push(`window=${formatDuration(window.limit_window_seconds * 1000)}`);
  }
  if (typeof window.reset_at === "number") {
    parts.push(`resets=${formatDuration(window.reset_at * 1000 - Date.now())}`);
  } else if (typeof window.reset_after_seconds === "number") {
    parts.push(`resets=${formatDuration(window.reset_after_seconds * 1000)}`);
  }
  return parts.length > 0 ? parts.join(", ") : "n/a";
}

function shortId(id: string | undefined): string {
  if (!id) return "?";
  return id.length > 32 ? `${id.slice(0, 24)}…${id.slice(-6)}` : id;
}

function summarizeCredits(credits: ResetCreditsResponse): string {
  const rows = (credits.credits ?? [])
    .slice()
    .sort((a, b) => Date.parse(a.expires_at ?? "") - Date.parse(b.expires_at ?? ""))
    .map((credit) => {
      const marker = credit.status === "available" ? "●" : "○";
      return [
        `${marker} ${shortId(credit.id)}`,
        `status=${credit.status ?? "?"}`,
        `expires=${formatDate(credit.expires_at)}`,
        credit.title ? `“${credit.title}”` : null,
      ]
        .filter((part): part is string => Boolean(part))
        .join("  ");
    });

  return [`banked resets: ${credits.available_count ?? 0} available`, ...rows].join("\n");
}

function summarizeUsage(usage: UsageResponse | null): string {
  if (!usage?.rate_limit) return "usage: n/a";
  return [
    "current usage:",
    `  primary  : ${formatWindow(usage.rate_limit.primary_window)}`,
    `  secondary: ${formatWindow(usage.rate_limit.secondary_window)}`,
  ].join("\n");
}

function errorMessage(error: unknown): string {
  if (!(error instanceof CodexResetError)) {
    return error instanceof Error ? error.message : String(error);
  }

  const parts = [error.message];
  if (error.status) parts.push(`HTTP ${error.status}`);
  if (error.body !== undefined) {
    const body = typeof error.body === "string" ? error.body : JSON.stringify(error.body);
    parts.push(body.slice(0, 800));
  }
  return parts.join("\n");
}

function availableCredits(credits: ResetCreditsResponse): ResetCredit[] {
  return (credits.credits ?? [])
    .filter((credit) => credit.status === "available" && credit.id)
    .sort((a, b) => Date.parse(a.expires_at ?? "") - Date.parse(b.expires_at ?? ""));
}

function findCredit(credits: ResetCredit[], creditId: string | undefined): ResetCredit | null {
  if (!creditId) return credits[0] ?? null;

  const exact = credits.find((credit) => credit.id === creditId);
  if (exact) return exact;

  const matches = credits.filter((credit) => credit.id?.startsWith(creditId));
  return matches.length === 1 ? matches[0] : null;
}

async function runStatus(ctx: ExtensionCommandContext): Promise<void> {
  const auth = await loadAuth(ctx);
  const [credits, usage] = await Promise.all([
    requestJson<ResetCreditsResponse>(auth, "GET", "/wham/rate-limit-reset-credits"),
    requestJson<UsageResponse>(auth, "GET", "/wham/usage"),
  ]);
  ctx.ui.notify(`${summarizeCredits(credits)}\n\n${summarizeUsage(usage)}`, "info");
}

async function runConsume(args: Args, ctx: ExtensionCommandContext): Promise<void> {
  const auth = await loadAuth(ctx);
  const credits = await requestJson<ResetCreditsResponse>(
    auth,
    "GET",
    "/wham/rate-limit-reset-credits",
  );
  const available = availableCredits(credits);
  if (available.length === 0) {
    ctx.ui.notify("No available Codex reset credits.", "info");
    return;
  }

  const target = findCredit(available, args.creditId);
  if (!target?.id) {
    ctx.ui.notify(`No matching available Codex reset credit: ${args.creditId ?? "?"}`, "warning");
    return;
  }

  const summary = [
    `credit_id : ${shortId(target.id)}`,
    `reset_type: ${target.reset_type ?? "?"}`,
    `granted_at: ${target.granted_at ?? "?"}`,
    `expires_at: ${target.expires_at ?? "?"}`,
  ].join("\n");

  if (args.dryRun) {
    ctx.ui.notify(
      `--dry-run: show the Codex reset that would be consumed (nothing is actually consumed).\n\n${summary}`,
      "info",
    );
    return;
  }

  const ok = await ctx.ui.confirm(
    "Consume Codex reset?",
    `${summary}\n\nThis immediately consumes one banked rate-limit reset credit and cannot be undone.`,
  );
  if (!ok) {
    ctx.ui.notify("Cancelled Codex reset consumption.", "info");
    return;
  }

  const result = await requestJson<ConsumeResponse>(
    auth,
    "POST",
    "/wham/rate-limit-reset-credits/consume",
    {
      credit_id: target.id,
      redeem_request_id: randomUUID(),
    },
  );

  let usage: UsageResponse | null = null;
  try {
    usage = await requestJson<UsageResponse>(auth, "GET", "/wham/usage");
  } catch {
    // The credit has already been consumed; still report the consume result.
  }

  ctx.ui.notify(
    [
      "Codex reset consumed.",
      `code=${result.code ?? "?"}  windows_reset=${result.windows_reset ?? "?"}`,
      `redeemed_at=${result.credit?.redeemed_at ?? "?"}`,
      "",
      summarizeUsage(usage),
    ].join("\n"),
    "info",
  );
}

function getArgumentCompletions(argumentPrefix: string): AutocompleteItem[] | null {
  // pi replaces the whole argument prefix with item.value, not just the current word.
  const tokens = argumentPrefix.trimStart().split(/\s+/).filter(Boolean);
  const completingNewToken = argumentPrefix.endsWith(" ");
  const current = completingNewToken ? "" : (tokens.at(-1) ?? "");
  const first = tokens[0] ?? "";

  const commandItems: AutocompleteItem[] = [
    { value: "status", label: "status", description: "Show banked resets and current usage" },
    {
      value: "consume",
      label: "consume",
      description: "Consume an available reset after confirmation",
    },
    { value: "help", label: "help", description: "Show command help" },
  ];

  if (tokens.length <= 1 && !completingNewToken) {
    return commandItems.filter((item) => item.value.startsWith(current));
  }

  if (first !== "consume") return null;

  const baseTokens = completingNewToken ? tokens : tokens.slice(0, -1);
  const base = baseTokens.join(" ");
  const withBase = (flag: string): string => (base ? `${base} ${flag}` : flag);
  const flagItems: AutocompleteItem[] = [
    { value: withBase("--dry-run"), label: "--dry-run", description: "Preview without consuming" },
    {
      value: withBase("--credit"),
      label: "--credit <id-prefix>",
      description: "Choose a specific available credit",
    },
  ];
  const matches = flagItems.filter((item) => item.label.startsWith(current));
  return matches.length > 0 ? matches : null;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("codex-reset", {
    description: "Show or consume OpenAI Codex banked rate-limit reset credits",
    getArgumentCompletions,
    handler: async (rawArgs, ctx) => {
      const args = parseArgs(rawArgs, "status");
      try {
        if (args.command === "help") {
          ctx.ui.notify(
            [
              "Usage:",
              "  /codex-reset                               Show banked resets and current usage",
              "  /codex-reset consume                       Consume an available reset (with confirmation)",
              "  /codex-reset consume --dry-run",
              "  /codex-reset consume --credit <id-prefix>",
            ].join("\n"),
            "info",
          );
          return;
        }

        if (args.command === "consume") {
          await runConsume(args, ctx);
        } else {
          await runStatus(ctx);
        }
      } catch (error) {
        ctx.ui.notify(`Codex reset failed:\n${errorMessage(error)}`, "error");
      }
    },
  });
}
