import { Buffer } from "node:buffer";
import { randomUUID } from "node:crypto";
import { CODEBUDDY_DEFAULT_DOMAIN, EXPIRY_BUFFER_MS, SUCCESS_CODES } from "./constants.js";

// ── JWT ──────────────────────────────────────────────────────────────────────

export function decodeCodebuddyJwtClaims(
  accessToken: string | undefined,
): Record<string, string | undefined> {
  if (!accessToken) return {};
  const parts = accessToken.split(".");
  if (parts.length < 2) return {};
  try {
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as Record<
      string,
      unknown
    >;
    return {
      sub: normalizeNonEmpty(payload.sub),
      email: normalizeNonEmpty(payload.email),
      preferred_username: normalizeNonEmpty(payload.preferred_username),
      name: normalizeNonEmpty(payload.name),
    };
  } catch {
    return {};
  }
}

export function decodeCodebuddyUserId(accessToken: string | undefined): string | undefined {
  return normalizeNonEmpty(decodeCodebuddyJwtClaims(accessToken).sub);
}

// ── Domain ───────────────────────────────────────────────────────────────────

export function normalizeDomain(domain: unknown): string {
  return normalizeNonEmpty(domain) || CODEBUDDY_DEFAULT_DOMAIN;
}

// ── Value normalization ──────────────────────────────────────────────────────

export function normalizeNonEmpty(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
}

/** Return the first argument that normalizes to a non-empty string. */
export function firstNonEmpty(...values: unknown[]): string | undefined {
  for (const value of values) {
    const normalized = normalizeNonEmpty(value);
    if (normalized) return normalized;
  }
  return undefined;
}

// ── Response parsing ─────────────────────────────────────────────────────────

export function readCode(payload: unknown): number | null {
  if (typeof payload !== "object" || payload == null) return null;
  return parseNumeric((payload as Record<string, unknown>).code);
}

export function readMessage(payload: unknown): string {
  if (typeof payload === "string") return payload.trim();
  if (typeof payload !== "object" || payload == null) return "";
  const record = payload as Record<string, unknown>;
  return normalizeNonEmpty(record.message) || normalizeNonEmpty(record.msg) || "";
}

export function readString(
  value: Record<string, unknown> | null | undefined,
  keys: string[],
): string {
  for (const key of keys) {
    const current = normalizeNonEmpty(value?.[key]);
    if (current) return current;
  }
  return "";
}

export function readHeader(
  headers: Record<string, string> | undefined,
  key: string,
): string | undefined {
  if (!headers) return undefined;
  const target = key.toLowerCase();
  for (const [headerKey, value] of Object.entries(headers)) {
    if (headerKey.toLowerCase() === target && value.trim()) return value.trim();
  }
  return undefined;
}

export function readBoolean(
  value: Record<string, unknown> | null | undefined,
  keys: string[],
): boolean {
  return keys.some((key) => value?.[key] === true);
}

export function readArray(
  value: Record<string, unknown> | null | undefined,
  keys: string[],
): unknown[] | null {
  for (const key of keys) {
    const current = value?.[key];
    if (Array.isArray(current)) return current;
  }
  return null;
}

export function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

// ── Numeric parsing ──────────────────────────────────────────────────────────

function parseNumeric(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function normalizeEpochMs(value: number | null): number | null {
  if (value == null || !Number.isFinite(value) || value <= 0) return null;
  return value > 10_000_000_000 ? Math.trunc(value) : Math.trunc(value * 1000);
}

export function parseExpiry(expiresAt: unknown, expiresIn: unknown): number | undefined {
  const direct = normalizeEpochMs(parseNumeric(expiresAt));
  if (direct) return direct - EXPIRY_BUFFER_MS;
  const seconds = parseNumeric(expiresIn);
  if (seconds && seconds > 0) return Date.now() + seconds * 1000 - EXPIRY_BUFFER_MS;
  return undefined;
}

// ── Identity / ID helpers ────────────────────────────────────────────────────

export function requestId(): string {
  return randomUUID().replaceAll("-", "");
}

export function toAbsoluteUrl(baseUrl: string, value: string): string {
  try {
    return new URL(value, baseUrl).toString();
  } catch {
    return value;
  }
}

// ── Collections ──────────────────────────────────────────────────────────────

export function uniqueStrings(values: Array<string | undefined>): string[] {
  return [...new Set(values.filter((v): v is string => Boolean(v)))];
}

// ── Environment ──────────────────────────────────────────────────────────────

export function stainlessOs(): string {
  switch (process.platform) {
    case "darwin":
      return "MacOS";
    case "win32":
      return "Windows";
    default:
      return "Linux";
  }
}

// ── Async helpers ────────────────────────────────────────────────────────────

export async function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  if (signal?.aborted) throw new Error("CodeBuddy authorization cancelled");
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      resolve();
    }, ms);
    const onAbort = () => {
      cleanup();
      reject(new Error("CodeBuddy authorization cancelled"));
    };
    const cleanup = () => {
      clearTimeout(timer);
      signal?.removeEventListener("abort", onAbort);
    };
    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

// ── HTTP ─────────────────────────────────────────────────────────────────────

export async function requestJson<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, init);
  const text = await response.text();
  let payload: unknown = null;
  let parseError: Error | null = null;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch (e) {
    parseError = e as Error;
  }

  if (!response.ok) {
    const message = readMessage(payload) || text || response.statusText;
    throw new Error(`HTTP ${response.status}: ${message}`);
  }

  if (parseError) {
    throw new Error(`Invalid JSON response: ${parseError.message}`);
  }

  return payload as T;
}

// ── Sequential fallback ─────────────────────────────────────────────────────

/** Try each item in sequence; return the first successful result, or throw the last error. */
export async function tryEach<T, U>(
  items: T[],
  fn: (item: T, index: number) => Promise<U>,
): Promise<U> {
  if (items.length === 0) throw new Error("tryEach: no items to try");
  let lastError: unknown;
  for (let i = 0; i < items.length; i++) {
    try {
      return await fn(items[i], i);
    } catch (error) {
      lastError = error;
    }
  }
  throw asError(lastError);
}

// ── Error ───────────────────────────────────────────────────────────────────

/** Convert any thrown value into a proper Error instance. */
export function asError(value: unknown): Error {
  return value instanceof Error ? value : new Error(String(value));
}

// ── Guard ────────────────────────────────────────────────────────────────────

export function ensureSuccess(payload: unknown, fallbackMessage: string): void {
  const code = readCode(payload);
  if (code == null || SUCCESS_CODES.has(code)) return;
  throw new Error(readMessage(payload) || `${fallbackMessage} (code=${code})`);
}
