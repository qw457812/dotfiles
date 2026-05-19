// ── Provider ────────────────────────────────────────────────────────────────
export const CODEBUDDY_PROVIDER = "codebuddy";

// ── Base URLs ───────────────────────────────────────────────────────────────
export const CODEBUDDY_CLI_BASE_URL = "https://copilot.tencent.com";
export const CODEBUDDY_ACCOUNT_BASE_URL = "https://www.codebuddy.cn";
export const CODEBUDDY_CHAT_BASE_URL = "https://copilot.tencent.com/v2";
export const CODEBUDDY_DEFAULT_DOMAIN = new URL(CODEBUDDY_ACCOUNT_BASE_URL).host;

// ── Expiry buffer ───────────────────────────────────────────────────────────
export const EXPIRY_BUFFER_MS = 5 * 60 * 1000; // 5-minute buffer before token expiry

// ── HTTP / polling ──────────────────────────────────────────────────────────
export const POLL_INTERVAL_MS = 1500;
export const POLL_TIMEOUT_MS = 10 * 60 * 1000;
export const SUCCESS_CODES = new Set([0, 200]);
export const PENDING_CODES = new Set([11217]);

// ── Product metadata ─────────────────────────────────────────────────────────
export const CODEBUDDY_VERSION = "2.97.3";
export const CODEBUDDY_USER_AGENT = `CLI/${CODEBUDDY_VERSION} CodeBuddy/${CODEBUDDY_VERSION}`;
export const CODEBUDDY_PRODUCT = "SaaS";
