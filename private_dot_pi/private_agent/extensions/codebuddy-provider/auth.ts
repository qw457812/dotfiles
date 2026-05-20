import type { OAuthCredentials, OAuthLoginCallbacks } from "@earendil-works/pi-ai";
import {
  ACCOUNTS_PATH,
  ACCOUNT_BASE_URL,
  AUTH_REFRESH_PATH,
  AUTH_STATE_PATH,
  AUTH_TOKEN_PATH,
  CLI_BASE_URL,
  DEFAULT_DOMAIN,
  PENDING_CODES,
  POLL_INTERVAL_MS,
  POLL_TIMEOUT_MS,
  PRODUCT,
  SUCCESS_CODES,
  USER_AGENT,
} from "./constants.js";
import type {
  AccountsData,
  ApiResponse,
  AuthPlatform,
  AuthState,
  AuthStateData,
  CodebuddyOAuthCredentials,
  Profile,
  TokenData,
  TokenPayload,
} from "./types.js";
import {
  asError,
  decodeJwtClaims,
  ensureSuccess,
  firstNonEmpty,
  normalizeDomain,
  normalizeNonEmpty,
  parseExpiry,
  readResponseCode,
  readResponseMessage,
  requestId,
  requestJson,
  sleep,
  toAbsoluteUrl,
  tryEach,
  uniqueStrings,
} from "./utils.js";

// ── Auth headers ─────────────────────────────────────────────────────────────

const NO_AUTH_HEADERS: Record<string, string> = {
  "X-No-Authorization": "true",
  "X-No-User-Id": "true",
  "X-No-Enterprise-Id": "true",
  "X-No-Department-Info": "true",
};

const COMMON_HEADERS: Record<string, string> = {
  Accept: "application/json, text/plain, */*",
  "User-Agent": USER_AGENT,
  "X-Requested-With": "XMLHttpRequest",
  "X-Product": PRODUCT,
};

// ── Public API ───────────────────────────────────────────────────────────────

export async function loginCodebuddy(
  callbacks: OAuthLoginCallbacks,
): Promise<CodebuddyOAuthCredentials> {
  const authState = await fetchAuthState(callbacks.signal);
  callbacks.onAuth({
    url: authState.authUrl,
    instructions: "Complete authorization in the browser. Pi will continue automatically.",
  });
  callbacks.onProgress?.("Waiting for CodeBuddy authorization...");

  const token = await pollToken(authState, callbacks.signal);
  return enrichCredentials(
    {
      access: token.accessToken,
      refresh: token.refreshToken,
      expires: token.expires,
      domain: token.domain,
      authBaseUrl: authState.baseUrl,
      authPlatform: authState.platform,
      accountBaseUrl: ACCOUNT_BASE_URL,
    },
    callbacks.signal,
  );
}

export async function refreshCodebuddyCredentials(
  credentials: OAuthCredentials,
  signal?: AbortSignal,
): Promise<CodebuddyOAuthCredentials> {
  const current = normalizeCredentials(credentials as CodebuddyOAuthCredentials);
  if (!current.refresh) {
    throw new Error("CodeBuddy refresh token missing. Please run /login codebuddy again");
  }

  const baseUrls = uniqueStrings([current.authBaseUrl, CLI_BASE_URL, ACCOUNT_BASE_URL]);

  return tryEach(baseUrls, async (baseUrl) => {
    const payload = await requestJson<ApiResponse<TokenData>>(`${baseUrl}${AUTH_REFRESH_PATH}`, {
      method: "POST",
      headers: {
        ...COMMON_HEADERS,
        Authorization: `Bearer ${current.access}`,
        "Content-Type": "application/json",
        "X-Domain": normalizeDomain(current.domain),
        "X-Refresh-Token": current.refresh,
        "X-Auth-Refresh-Source": "plugin",
        "X-Request-ID": requestId(),
        ...(current.userId ? { "X-User-Id": current.userId } : {}),
      },
      body: "{}",
      signal,
    });
    ensureSuccess(payload, "Token refresh failed");
    const data = payload.data;
    const accessToken = data?.accessToken || data?.access_token;
    if (!accessToken) {
      throw new Error("Token refresh response missing accessToken");
    }

    return enrichCredentials(
      {
        ...current,
        access: accessToken,
        refresh: data?.refreshToken || data?.refresh_token || current.refresh,
        expires: parseExpiry(data?.expiresAt, data?.expiresIn) ?? current.expires,
        domain: data?.domain || current.domain,
        authBaseUrl: baseUrl,
        accountBaseUrl: current.accountBaseUrl || ACCOUNT_BASE_URL,
      },
      signal,
    );
  });
}

// ── Private: credentials ─────────────────────────────────────────────────────

async function enrichCredentials(
  credentials: CodebuddyOAuthCredentials,
  signal?: AbortSignal,
): Promise<CodebuddyOAuthCredentials> {
  if (!needsProfileEnrichment(credentials)) return normalizeCredentials(credentials);

  try {
    const profile = await fetchProfile(credentials, signal);
    const merged: CodebuddyOAuthCredentials = {
      ...credentials,
      userId: credentials.userId || profile.userId,
      uid: credentials.uid || profile.uid,
      email: credentials.email || profile.email,
      nickname: credentials.nickname || profile.nickname,
      enterpriseId: credentials.enterpriseId || profile.enterpriseId,
      enterpriseName: credentials.enterpriseName || profile.enterpriseName,
      departmentFullName: credentials.departmentFullName || profile.departmentFullName,
    };
    return normalizeCredentials(merged);
  } catch {
    return normalizeCredentials(credentials);
  }
}

function normalizeCredentials(credentials: CodebuddyOAuthCredentials): CodebuddyOAuthCredentials {
  const domain = normalizeDomain(credentials.domain);
  const decoded = decodeJwtClaims(credentials.access);
  const userId = firstNonEmpty(credentials.userId, credentials.uid, decoded.sub);
  const email = firstNonEmpty(credentials.email, decoded.email, decoded.preferred_username);
  const nickname = firstNonEmpty(credentials.nickname, decoded.name);

  return {
    ...credentials,
    userId,
    uid: normalizeNonEmpty(credentials.uid) || userId,
    email: email || nickname || userId,
    nickname: nickname || email || userId,
    enterpriseId: normalizeNonEmpty(credentials.enterpriseId),
    enterpriseName: normalizeNonEmpty(credentials.enterpriseName),
    domain,
    authBaseUrl: credentials.authBaseUrl || CLI_BASE_URL,
    accountBaseUrl: credentials.accountBaseUrl || ACCOUNT_BASE_URL,
  };
}

function needsProfileEnrichment(credentials: CodebuddyOAuthCredentials): boolean {
  return (
    !firstNonEmpty(credentials.userId, credentials.uid) ||
    !normalizeNonEmpty(credentials.email) ||
    !normalizeNonEmpty(credentials.nickname) ||
    !normalizeNonEmpty(credentials.enterpriseId)
  );
}

// ── Private: auth state ──────────────────────────────────────────────────────

async function fetchAuthState(signal?: AbortSignal): Promise<AuthState> {
  const attempts: Array<{
    baseUrl: string;
    platform: AuthPlatform;
  }> = [
    { baseUrl: CLI_BASE_URL, platform: "cli" },
    { baseUrl: ACCOUNT_BASE_URL, platform: "ide" },
  ];

  return tryEach(attempts, async (attempt) => {
    const payload = await requestJson<ApiResponse<AuthStateData>>(
      `${attempt.baseUrl}${AUTH_STATE_PATH}?platform=${attempt.platform}`,
      {
        method: "POST",
        headers: {
          ...COMMON_HEADERS,
          ...NO_AUTH_HEADERS,
          "Content-Type": "application/json",
          "X-Request-ID": requestId(),
        },
        body: "{}",
        signal,
      },
    );
    ensureSuccess(payload, "Failed to get CodeBuddy authorization URL");
    const data = payload.data;
    const state = data?.state || "";
    const authUrl =
      data?.authUrl ||
      data?.auth_url ||
      data?.url ||
      `${attempt.baseUrl}/login?state=${encodeURIComponent(state)}`;
    if (!state || !authUrl) {
      throw new Error("CodeBuddy authorization response missing state or authUrl");
    }
    return {
      baseUrl: attempt.baseUrl,
      platform: attempt.platform,
      state,
      authUrl: toAbsoluteUrl(attempt.baseUrl, authUrl),
    };
  });
}

// ── Private: token polling ───────────────────────────────────────────────────

async function pollToken(authState: AuthState, signal?: AbortSignal): Promise<TokenPayload> {
  const url = `${authState.baseUrl}${AUTH_TOKEN_PATH}?state=${encodeURIComponent(authState.state)}`;
  const deadline = Date.now() + POLL_TIMEOUT_MS;

  while (Date.now() < deadline) {
    if (signal?.aborted) {
      throw new Error("CodeBuddy authorization cancelled");
    }

    try {
      const payload = await requestJson<ApiResponse<TokenData>>(url, {
        headers: {
          ...COMMON_HEADERS,
          ...NO_AUTH_HEADERS,
        },
        signal,
      });
      const code = readResponseCode(payload);
      if (code !== null && SUCCESS_CODES.has(code)) {
        const data = payload.data;
        const accessToken = data?.accessToken || data?.access_token;
        if (!accessToken) {
          throw new Error("CodeBuddy authorization response missing accessToken");
        }
        return {
          accessToken,
          refreshToken: data?.refreshToken || data?.refresh_token || "",
          expires:
            parseExpiry(data?.expiresAt, data?.expiresIn) || Date.now() + 24 * 60 * 60 * 1000,
          domain: data?.domain || DEFAULT_DOMAIN,
        };
      }
      if (code !== null && !SUCCESS_CODES.has(code) && !PENDING_CODES.has(code)) {
        throw new Error(
          readResponseMessage(payload) || `CodeBuddy authorization failed (code=${code})`,
        );
      }
    } catch (error) {
      if (signal?.aborted) {
        throw new Error("CodeBuddy authorization cancelled");
      }
      if (Date.now() + POLL_INTERVAL_MS >= deadline) {
        throw asError(error);
      }
    }

    await sleep(POLL_INTERVAL_MS, signal);
  }

  throw new Error("CodeBuddy authorization timed out. Please try again");
}

// ── Private: profile ─────────────────────────────────────────────────────────

async function fetchProfile(
  credentials: CodebuddyOAuthCredentials,
  signal?: AbortSignal,
): Promise<Profile> {
  const urls = uniqueStrings([
    credentials.accountBaseUrl,
    credentials.authBaseUrl,
    ACCOUNT_BASE_URL,
  ]);

  return tryEach(urls, async (baseUrl) => {
    const payload = await requestJson<ApiResponse<AccountsData>>(`${baseUrl}${ACCOUNTS_PATH}`, {
      headers: {
        ...COMMON_HEADERS,
        Authorization: `Bearer ${credentials.access}`,
        "X-Domain": normalizeDomain(credentials.domain),
      },
      signal,
    });
    if (readResponseCode(payload) !== null) {
      ensureSuccess(payload, "Failed to fetch CodeBuddy account info");
    }
    const data = payload.data;
    const accounts = data?.accounts || data?.Accounts;
    const selected = accounts?.find((a) => a.lastLogin === true) || accounts?.[0];
    if (!selected) {
      throw new Error("CodeBuddy account info is empty");
    }
    const uid = selected.uid || selected.id || "";
    const nickname = selected.nickname || selected.label || selected.name || "";
    const email = selected.email || "";
    const enterpriseId = selected.enterpriseId || selected.enterprise_id || "";
    const enterpriseName = selected.enterpriseName || selected.enterprise_name || "";
    const departmentFullName =
      selected.departmentFullName || selected.department_full_name || selected.deptFullName || "";
    return {
      userId: uid,
      uid,
      email: email || nickname || uid,
      nickname: nickname || email || uid,
      enterpriseId,
      enterpriseName,
      departmentFullName,
    };
  });
}
