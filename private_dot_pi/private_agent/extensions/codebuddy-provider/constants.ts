// ── Provider ────────────────────────────────────────────────────────────────
export const PROVIDER = "codebuddy";

// ── Base URLs ───────────────────────────────────────────────────────────────
export const CLI_BASE_URL = "https://copilot.tencent.com";
export const ACCOUNT_BASE_URL = "https://www.codebuddy.cn";
export const CHAT_BASE_URL = "https://copilot.tencent.com/v2";
export const DEFAULT_DOMAIN = "www.codebuddy.cn";

// ── Auth API paths (CLI mode, prefixPath="/plugin") ─────────────────────
export const AUTH_STATE_PATH = "/v2/plugin/auth/state";
export const AUTH_TOKEN_PATH = "/v2/plugin/auth/token";
export const AUTH_REFRESH_PATH = "/v2/plugin/auth/token/refresh";
export const ACCOUNTS_PATH = "/v2/plugin/accounts";

// ── Expiry buffer ───────────────────────────────────────────────────────────
export const EXPIRY_BUFFER_MS = 5 * 60 * 1000; // 5-minute buffer before token expiry

// ── HTTP / polling ──────────────────────────────────────────────────────────
export const POLL_INTERVAL_MS = 1000;
export const POLL_TIMEOUT_MS = 5 * 60 * 1000;
export const SUCCESS_CODES = new Set([0, 200]);
export const PENDING_CODES = new Set([11217]);

// ── Product metadata ────────────────────────────────────────────────────────
export const VERSION = "2.97.3";
export const USER_AGENT = `CLI/${VERSION} CodeBuddy/${VERSION}`;
export const PRODUCT = "SaaS";
