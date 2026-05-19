import type { OAuthCredentials, OAuthLoginCallbacks } from "@earendil-works/pi-ai";
import {
  CODEBUDDY_ACCOUNT_BASE_URL,
  CODEBUDDY_CLI_BASE_URL,
  CODEBUDDY_DEFAULT_DOMAIN,
  CODEBUDDY_PRODUCT,
  CODEBUDDY_USER_AGENT,
  PENDING_CODES,
  POLL_INTERVAL_MS,
  POLL_TIMEOUT_MS,
  SUCCESS_CODES,
} from "./constants.js";
import type {
  CodebuddyAuthPlatform,
  CodebuddyAuthState,
  CodebuddyOAuthCredentials,
  CodebuddyTokenPayload,
  CodebuddyProfile,
} from "./types.js";
import {
  asError,
  asRecord,
  requestJson,
  decodeCodebuddyJwtClaims,
  ensureSuccess,
  firstNonEmpty,
  normalizeDomain,
  normalizeNonEmpty,
  parseExpiry,
  readArray,
  readBoolean,
  readCode,
  readMessage,
  readString,
  requestId,
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
  "User-Agent": CODEBUDDY_USER_AGENT,
  "X-Requested-With": "XMLHttpRequest",
  "X-Product": CODEBUDDY_PRODUCT,
};

// ── Public API ───────────────────────────────────────────────────────────────

export async function loginCodebuddy(
  callbacks: OAuthLoginCallbacks,
): Promise<CodebuddyOAuthCredentials> {
  const authState = await fetchCodebuddyAuthState(callbacks.signal);
  callbacks.onAuth({
    url: authState.authUrl,
    instructions: "Complete authorization in the browser. Pi will continue automatically.",
  });
  callbacks.onProgress?.("Waiting for CodeBuddy authorization...");

  const token = await pollCodebuddyToken(authState, callbacks.signal);
  const credentials = await enrichCodebuddyCredentials(
    {
      access: token.accessToken,
      refresh: token.refreshToken,
      expires: token.expires,
      domain: token.domain,
      authBaseUrl: authState.baseUrl,
      authPlatform: authState.platform,
      accountBaseUrl: CODEBUDDY_ACCOUNT_BASE_URL,
    },
    callbacks.signal,
  );

  return credentials;
}

export async function refreshCodebuddyCredentials(
  credentials: OAuthCredentials,
  signal?: AbortSignal,
): Promise<CodebuddyOAuthCredentials> {
  const current = normalizeCredentials(credentials as CodebuddyOAuthCredentials);
  if (!current.refresh) {
    throw new Error("CodeBuddy refresh token missing. Please run /login codebuddy again");
  }

  const baseUrls = uniqueStrings([
    current.authBaseUrl,
    CODEBUDDY_CLI_BASE_URL,
    CODEBUDDY_ACCOUNT_BASE_URL,
  ]);

  return tryEach(baseUrls, async (baseUrl) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const payload = await requestJson<any>(`${baseUrl}/v2/plugin/auth/token/refresh`, {
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
    const data = asRecord(payload?.data);
    const accessToken = readString(data, ["accessToken", "access_token"]);
    if (!accessToken) {
      throw new Error("Token refresh response missing accessToken");
    }

    return enrichCodebuddyCredentials(
      {
        ...current,
        access: accessToken,
        refresh: readString(data, ["refreshToken", "refresh_token"]) || current.refresh,
        expires:
          parseExpiry(data?.expiresAt, data?.expires_in ?? data?.expiresIn) ?? current.expires,
        domain: readString(data, ["domain"]) || current.domain,
        authBaseUrl: baseUrl,
        accountBaseUrl: current.accountBaseUrl || CODEBUDDY_ACCOUNT_BASE_URL,
      },
      signal,
    );
  });
}

async function enrichCodebuddyCredentials(
  credentials: CodebuddyOAuthCredentials,
  signal?: AbortSignal,
): Promise<CodebuddyOAuthCredentials> {
  const next = normalizeCredentials(credentials);
  if (!needsProfileEnrichment(next)) return next;

  try {
    const profile = await fetchCodebuddyProfile(next, signal);
    const mergeFields: Partial<CodebuddyOAuthCredentials> = {};
    for (const key of [
      "userId",
      "uid",
      "email",
      "nickname",
      "enterpriseId",
      "enterpriseName",
    ] as const) {
      const profileValue = profile[key];
      if (profileValue) mergeFields[key] = profileValue;
    }
    return normalizeCredentials({ ...next, ...mergeFields });
  } catch {
    return next;
  }
}

function normalizeCredentials(credentials: CodebuddyOAuthCredentials): CodebuddyOAuthCredentials {
  const domain = normalizeDomain(credentials.domain);
  const decoded = decodeCodebuddyJwtClaims(credentials.access);
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
    authBaseUrl: credentials.authBaseUrl || CODEBUDDY_CLI_BASE_URL,
    accountBaseUrl: credentials.accountBaseUrl || CODEBUDDY_ACCOUNT_BASE_URL,
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

async function fetchCodebuddyAuthState(signal?: AbortSignal): Promise<CodebuddyAuthState> {
  const attempts: Array<{
    baseUrl: string;
    platform: CodebuddyAuthPlatform;
  }> = [
    { baseUrl: CODEBUDDY_CLI_BASE_URL, platform: "CLI" },
    { baseUrl: CODEBUDDY_ACCOUNT_BASE_URL, platform: "ide" },
  ];

  return tryEach(attempts, async (attempt) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const payload = await requestJson<any>(
      `${attempt.baseUrl}/v2/plugin/auth/state?platform=${attempt.platform}`,
      {
        method: "POST",
        headers: {
          ...COMMON_HEADERS,
          ...NO_AUTH_HEADERS,
          "Content-Type": "application/json",
          "X-Domain": attempt.baseUrl,
          "X-Request-ID": requestId(),
        },
        body: "{}",
        signal,
      },
    );
    ensureSuccess(payload, "Failed to get CodeBuddy authorization URL");
    const data = asRecord(payload?.data);
    const state = readString(data, ["state"]);
    const authUrl =
      readString(data, ["authUrl", "auth_url", "url"]) ||
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

async function pollCodebuddyToken(
  authState: CodebuddyAuthState,
  signal?: AbortSignal,
): Promise<CodebuddyTokenPayload> {
  const url = `${authState.baseUrl}/v2/plugin/auth/token?state=${encodeURIComponent(authState.state)}`;
  const deadline = Date.now() + POLL_TIMEOUT_MS;

  while (Date.now() < deadline) {
    if (signal?.aborted) {
      throw new Error("CodeBuddy authorization cancelled");
    }

    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const payload = await requestJson<any>(url, {
        headers: {
          ...COMMON_HEADERS,
          ...NO_AUTH_HEADERS,
        },
        signal,
      });
      const code = readCode(payload);
      if (code !== null && SUCCESS_CODES.has(code)) {
        const data = asRecord(payload?.data);
        const accessToken = readString(data, ["accessToken", "access_token"]);
        if (!accessToken) {
          throw new Error("CodeBuddy authorization response missing accessToken");
        }
        return {
          accessToken,
          refreshToken: readString(data, ["refreshToken", "refresh_token"]),
          expires:
            parseExpiry(data?.expiresAt, data?.expires_in ?? data?.expiresIn) ||
            Date.now() + 24 * 60 * 60 * 1000,
          domain: readString(data, ["domain"]) || CODEBUDDY_DEFAULT_DOMAIN,
        };
      }
      if (code !== null && !PENDING_CODES.has(code)) {
        throw new Error(readMessage(payload) || `CodeBuddy authorization failed (code=${code})`);
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

async function fetchCodebuddyProfile(
  credentials: CodebuddyOAuthCredentials,
  signal?: AbortSignal,
): Promise<CodebuddyProfile> {
  const urls = uniqueStrings([
    credentials.accountBaseUrl,
    credentials.authBaseUrl,
    CODEBUDDY_ACCOUNT_BASE_URL,
  ]);

  return tryEach(urls, async (baseUrl) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const payload = await requestJson<any>(`${baseUrl}/v2/plugin/accounts`, {
      headers: {
        ...COMMON_HEADERS,
        Authorization: `Bearer ${credentials.access}`,
        "X-Domain": normalizeDomain(credentials.domain),
      },
      signal,
    });
    if (readCode(payload) !== null) {
      ensureSuccess(payload, "Failed to fetch CodeBuddy account info");
    }
    const data = asRecord(payload?.data);
    const accounts =
      readArray(data, ["accounts", "Accounts"]) || readArray(payload, ["accounts", "Accounts"]);
    const selected =
      accounts?.find((item) => readBoolean(asRecord(item), ["lastLogin"])) || accounts?.[0];
    const account = asRecord(selected);
    if (!account) {
      throw new Error("CodeBuddy account info is empty");
    }
    const uid = readString(account, ["uid", "id"]);
    const nickname = readString(account, ["nickname", "label", "name"]);
    const email = readString(account, ["email"]);
    const enterpriseId = readString(account, ["enterpriseId", "enterprise_id"]);
    const enterpriseName = readString(account, ["enterpriseName", "enterprise_name"]);
    return {
      userId: uid,
      uid,
      email: email || nickname || uid,
      nickname: nickname || email || uid,
      enterpriseId,
      enterpriseName,
    };
  });
}
