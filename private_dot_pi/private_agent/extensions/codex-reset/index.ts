/**
 * Codex banked rate-limit reset helper.
 *
 * While Pi is running, check every minute and automatically consume at most one
 * available credit expiring within five minutes. Usage is not a prerequisite.
 * Automatic credit-list checks share a persisted 60-second cooldown per account.
 * Manual commands bypass this polling cooldown.
 * Consumption attempts are persisted before POST and serialized per account.
 * Retries after ambiguous failures reuse the same request ID across Pi instances,
 * reloads and manual commands.
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
 * ../custom-footer/quota.ts for Codex reset-credit status.
 *
 * References (pinned to the inspected revisions):
 * - Official protocol: one ID per logical attempt, reuse on retry; outcome meanings.
 *   https://github.com/openai/codex/blob/a29c7b97e88367044ae84c28c85451ec3e72af9f/codex-rs/app-server-protocol/src/protocol/v2/account.rs#L430-L461
 * - Official backend client: idempotency_key is sent as redeem_request_id.
 *   https://github.com/openai/codex/blob/a29c7b97e88367044ae84c28c85451ec3e72af9f/codex-rs/app-server/src/request_processors/account_processor/rate_limit_resets.rs#L45-L78
 *   https://github.com/openai/codex/blob/a29c7b97e88367044ae84c28c85451ec3e72af9f/codex-rs/backend-client/src/client/rate_limit_resets.rs#L89-L122
 * - Official CLI regression: a lost response retries the same request ID and credit ID.
 *   https://github.com/openai/codex/blob/a29c7b97e88367044ae84c28c85451ec3e72af9f/codex-rs/tui/src/chatwidget/tests/usage.rs#L658-L687
 * - Reference helper: UUID generation for a single explicit-credit submission (no persisted retry state).
 *   https://github.com/aaamosh/codex-reset/blob/d8105e16fb74c544c3a03a3924c96b1ab90b8375/codex_reset.py#L372-L414
 * - Reference extension: pending request ID reuse for retries of the same account/card.
 *   https://github.com/99percentpeople/pi-extensions/blob/a7ae6b89a211c35b657e886e9ceeafbf51616c22/extensions/codex-api/usage.ts#L1214-L1265
 */

import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";
import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import lockfile from "proper-lockfile";

const PROVIDER = "openai-codex";
const BASE_URL = "https://chatgpt.com/backend-api";
const FETCH_TIMEOUT_MS = 30_000;
const JWT_CLAIM_PATH = "https://api.openai.com/auth";
const AUTO_POLL_INTERVAL_MS = 60_000;
const AUTO_CONSUME_WINDOW_MS = 5 * AUTO_POLL_INTERVAL_MS;

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

type ConsumeCode = "reset" | "already_redeemed" | "nothing_to_reset" | "no_credit";

interface ConsumeAttempt {
  creditId: string;
  expiresAt: string | null;
  redeemRequestId: string;
  status: "pending" | ConsumeCode;
  lastAttemptAt: number;
}

interface CodexResetState {
  accountId: string;
  lastAutoPollStartedAt: number;
  attempts: ConsumeAttempt[];
}

type ConsumeResult =
  | { credit: ResetCredit; response: ConsumeResponse & { code: ConsumeCode } }
  | { skipped: "busy" | "already_consumed" | "unavailable" | "poll_cooldown" | "retry_cooldown" };

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

async function loadAuth(ctx: ExtensionContext): Promise<CodexAuth> {
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
  signal?: AbortSignal,
): Promise<T> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${auth.token}`,
    "ChatGPT-Account-Id": auth.accountId,
    originator: "pi",
    "User-Agent": "pi-codex-reset",
  };
  const init: RequestInit = {
    method,
    signal: AbortSignal.any([AbortSignal.timeout(FETCH_TIMEOUT_MS), ...(signal ? [signal] : [])]),
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

function hash(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function statePath(accountId: string): string {
  return join(getAgentDir(), "codex-reset-state", `${hash(accountId)}.json`);
}

function expiresSoon(expiresAt: string | null | undefined, now = Date.now()): boolean {
  const remaining = Date.parse(expiresAt ?? "") - now;
  return remaining > 0 && remaining <= AUTO_CONSUME_WINDOW_MS;
}

function isConsumeCode(code: unknown): code is ConsumeCode {
  return (
    code === "reset" ||
    code === "already_redeemed" ||
    code === "nothing_to_reset" ||
    code === "no_credit"
  );
}

function isConsumeSuccess(status: string): boolean {
  return status === "reset" || status === "already_redeemed";
}

async function loadState(path: string, accountId: string): Promise<CodexResetState> {
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT")
      return { accountId, lastAutoPollStartedAt: 0, attempts: [] };
    throw error;
  }
  const state = JSON.parse(raw) as CodexResetState;
  if (
    state?.accountId !== accountId ||
    !Number.isFinite(state.lastAutoPollStartedAt) ||
    !Array.isArray(state.attempts) ||
    !state.attempts.every(
      (attempt) =>
        attempt &&
        typeof attempt.creditId === "string" &&
        attempt.creditId &&
        typeof attempt.redeemRequestId === "string" &&
        attempt.redeemRequestId &&
        (attempt.expiresAt === null || typeof attempt.expiresAt === "string") &&
        (attempt.status === "pending" || isConsumeCode(attempt.status)) &&
        Number.isFinite(attempt.lastAttemptAt),
    ) ||
    new Set(state.attempts.map((attempt) => attempt.creditId)).size !== state.attempts.length
  ) {
    throw new CodexResetError(
      `Invalid Codex reset state: ${path}. Refusing to replace request IDs.`,
    );
  }
  return state;
}

async function saveState(path: string, state: CodexResetState, signal: AbortSignal): Promise<void> {
  const temporary = `${path}.${randomUUID()}.tmp`;
  try {
    signal.throwIfAborted();
    await writeFile(temporary, JSON.stringify(state), { flag: "wx", mode: 0o600 });
    signal.throwIfAborted();
    await rename(temporary, path);
  } finally {
    await rm(temporary, { force: true });
  }
}

/** All callers share a durable request ID and an inter-process account lock. */
async function consumeCredit(
  auth: CodexAuth,
  creditId?: string,
  signal?: AbortSignal,
): Promise<ConsumeResult> {
  const automatic = creditId === undefined;
  const directory = join(getAgentDir(), "codex-reset-state");
  const path = statePath(auth.accountId);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const lease = new AbortController();
  const operationSignal = AbortSignal.any([lease.signal, ...(signal ? [signal] : [])]);
  let release: () => Promise<void>;
  try {
    release = await lockfile.lock(path, {
      realpath: false,
      retries: 0,
      stale: 2 * AUTO_POLL_INTERVAL_MS,
      update: 10_000,
      onCompromised: (error) => lease.abort(error),
    });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ELOCKED") return { skipped: "busy" };
    throw error;
  }

  try {
    operationSignal.throwIfAborted();
    const state = await loadState(path, auth.accountId);
    if (automatic) {
      const now = Date.now();
      if (now - state.lastAutoPollStartedAt < AUTO_POLL_INTERVAL_MS)
        return { skipped: "poll_cooldown" };
      // Reserve the account's polling slot before GET, including failed requests.
      // Persist under the lock so staggered instances and reloads share the limit.
      state.lastAutoPollStartedAt = now;
      await saveState(path, state, operationSignal);
    }
    const credits = await requestJson<ResetCreditsResponse>(
      auth,
      "GET",
      "/wham/rate-limit-reset-credits",
      undefined,
      operationSignal,
    );
    // Resolve an unknown result before choosing another card, even if the backend
    // already reports the original card as redeeming/redeemed (or omits it).
    const pending = automatic
      ? state.attempts
          .filter((attempt) => attempt.status === "pending" && expiresSoon(attempt.expiresAt))
          .sort((a, b) => Date.parse(a.expiresAt!) - Date.parse(b.expiresAt!))[0]
      : undefined;
    const target =
      creditId || pending
        ? (credits.credits ?? []).find((credit) => credit.id === (creditId ?? pending?.creditId))
        : (credits.credits ?? [])
            .filter(
              (credit) =>
                credit.id &&
                credit.status === "available" &&
                expiresSoon(credit.expires_at) &&
                !state.attempts.some(
                  (attempt) => attempt.creditId === credit.id && isConsumeSuccess(attempt.status),
                ),
            )
            .sort((a, b) => Date.parse(a.expires_at!) - Date.parse(b.expires_at!))[0];
    if (!target?.id || (automatic && !expiresSoon(target.expires_at)))
      return { skipped: "unavailable" };
    const previous = state.attempts.find((attempt) => attempt.creditId === target.id);
    if (previous && isConsumeSuccess(previous.status)) return { skipped: "already_consumed" };
    if (previous?.status !== "pending" && target.status !== "available")
      return { skipped: "unavailable" };
    if (automatic && previous && Date.now() - previous.lastAttemptAt < AUTO_POLL_INTERVAL_MS)
      return { skipped: "retry_cooldown" };

    const attempt: ConsumeAttempt = {
      creditId: target.id,
      expiresAt: target.expires_at ?? null,
      redeemRequestId: previous?.status === "pending" ? previous.redeemRequestId : randomUUID(),
      status: "pending",
      lastAttemptAt: Date.now(),
    };
    if (previous) state.attempts[state.attempts.indexOf(previous)] = attempt;
    else state.attempts.push(attempt);
    // Publish the complete pending record atomically before any POST. A crash
    // after dispatch or a failed outcome write leaves the same ID for replay.
    await saveState(path, state, operationSignal);
    operationSignal.throwIfAborted();
    if (automatic && !expiresSoon(target.expires_at)) return { skipped: "unavailable" };
    if (!automatic && target.expires_at && Date.parse(target.expires_at) <= Date.now())
      return { skipped: "unavailable" };
    const response = await requestJson<ConsumeResponse>(
      auth,
      "POST",
      "/wham/rate-limit-reset-credits/consume",
      { credit_id: target.id, redeem_request_id: attempt.redeemRequestId },
      operationSignal,
    );
    const code = response?.code;
    if (!isConsumeCode(code)) {
      throw new CodexResetError(
        "Unknown Codex consumption outcome; preserving the request ID for retry.",
        undefined,
        response,
      );
    }
    attempt.status = code;
    await saveState(path, state, operationSignal);
    return { credit: target, response: { ...response, code } };
  } finally {
    await release().catch((error) => {
      if (!lease.signal.aborted) throw error;
    });
  }
}

/** Local skips are not evidence that a previous backend failure has recovered. */
async function runAutoConsume(ctx: ExtensionContext, signal: AbortSignal): Promise<boolean> {
  const token = await ctx.modelRegistry.getApiKeyForProvider(PROVIDER);
  if (!token || signal.aborted) return false;
  const accountId = extractAccountId(token);
  if (!accountId) return false;
  const result = await consumeCredit({ token, accountId }, undefined, signal);
  if (signal.aborted) return false;
  if ("skipped" in result) return result.skipped !== "busy" && result.skipped !== "poll_cooldown";
  const { credit, response } = result;
  if (isConsumeSuccess(response.code)) {
    ctx.ui.notify(
      `${response.code === "already_redeemed" ? "Confirmed previously consumed" : "Automatically consumed expiring"} Codex reset ${shortId(credit.id)} (expires ${credit.expires_at}).\ncode=${response.code}  windows_reset=${response.windows_reset ?? "?"}`,
      "info",
    );
  } else if (response.code === "no_credit") {
    ctx.ui.notify(
      `Codex reset ${shortId(credit.id)} is no longer available; no other credit was used.`,
      "warning",
    );
  }
  // nothing_to_reset is a definitive no-op, not success. The next check may
  // start a new logical attempt with a new ID, while still within the deadline.
  return true;
}

async function runConsume(args: Args, ctx: ExtensionCommandContext): Promise<void> {
  const auth = await loadAuth(ctx);
  const credits = await requestJson<ResetCreditsResponse>(
    auth,
    "GET",
    "/wham/rate-limit-reset-credits",
  );
  const state = await loadState(statePath(auth.accountId), auth.accountId);
  const pending = state.attempts.find(
    (attempt) =>
      attempt.status === "pending" &&
      (attempt.expiresAt === null || Date.parse(attempt.expiresAt) > Date.now()),
  );
  const target = args.creditId
    ? findCredit(credits.credits ?? [], args.creditId)
    : pending
      ? (credits.credits ?? []).find((credit) => credit.id === pending.creditId)
      : availableCredits(credits)[0];
  if (!target?.id) {
    ctx.ui.notify(
      pending && !args.creditId
        ? `Pending Codex reset ${shortId(pending.creditId)} is absent from the credit list; no other credit was selected.`
        : "No matching available Codex reset credit.",
      "warning",
    );
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
    `${summary}\n\nA successful reset consumes one banked credit and cannot be undone.`,
  );
  if (!ok) {
    ctx.ui.notify("Cancelled Codex reset consumption.", "info");
    return;
  }

  const confirmedAuth = await loadAuth(ctx);
  if (confirmedAuth.accountId !== auth.accountId) {
    ctx.ui.notify("Codex account changed during confirmation; no credit was submitted.", "warning");
    return;
  }
  const consumeResult = await consumeCredit(confirmedAuth, target.id);
  if ("skipped" in consumeResult) {
    ctx.ui.notify(
      `No Codex reset submitted (${consumeResult.skipped}); no other credit was used.`,
      "info",
    );
    return;
  }
  const result = consumeResult.response;
  if (!isConsumeSuccess(result.code)) {
    ctx.ui.notify(
      result.code === "nothing_to_reset"
        ? "No current Codex usage window needs a reset; no credit was consumed."
        : "The selected Codex reset is no longer available; no other credit was used.",
      result.code === "nothing_to_reset" ? "info" : "warning",
    );
    return;
  }

  let usage: UsageResponse | null = null;
  try {
    usage = await requestJson<UsageResponse>(confirmedAuth, "GET", "/wham/usage");
  } catch {
    // The credit has already been consumed; still report the consume result.
  }

  ctx.ui.notify(
    [
      result.code === "already_redeemed"
        ? "Confirmed previously consumed Codex reset."
        : "Codex reset consumed.",
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
  let timer: ReturnType<typeof setInterval> | undefined;
  let controller: AbortController | undefined;
  let running: Promise<void> | undefined;

  pi.on("session_start", (_event, ctx) => {
    const sessionController = new AbortController();
    controller = sessionController;
    let lastError = "";
    const check = () => {
      if (running || sessionController.signal.aborted) return;
      running = runAutoConsume(ctx, sessionController.signal)
        .then((checked) => {
          if (checked) lastError = "";
        })
        .catch((error) => {
          if (sessionController.signal.aborted) return;
          const message = errorMessage(error);
          if (message !== lastError) {
            ctx.ui.notify(`Codex auto-reset failed:\n${message}`, "warning");
            lastError = message;
          }
        })
        .finally(() => {
          running = undefined;
        });
    };
    timer = setInterval(check, AUTO_POLL_INTERVAL_MS);
    timer.unref();
    check();
  });

  pi.on("session_shutdown", async () => {
    clearInterval(timer);
    controller?.abort();
    await running;
    timer = undefined;
    controller = undefined;
  });

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
              "",
              "Auto: polls at most once per 60 seconds per account across Pi instances; consumes only available credits expiring within 5 minutes (no confirmation).",
              "Manual commands bypass the automatic polling cooldown.",
              "Unknown outcomes retry with the same persisted request ID; manual retries share it.",
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
