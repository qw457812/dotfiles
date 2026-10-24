import type { AuthInteraction } from "@earendil-works/pi-ai";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  codebuddyCredentialsToAuth,
  loginCodebuddy,
  refreshCodebuddyCredentials,
} from "../../extensions/codebuddy-provider/auth.js";
import {
  HTTP_TIMEOUT_MS,
  POLL_INTERVAL_MS,
  POLL_TIMEOUT_MS,
} from "../../extensions/codebuddy-provider/constants.js";
import type { CodebuddyOAuthCredentials } from "../../extensions/codebuddy-provider/types.js";
import { HttpError, requestJson, tryEach } from "../../extensions/codebuddy-provider/utils.js";

const json = (payload: unknown, status = 200) => new Response(JSON.stringify(payload), { status });
// Minimal unsigned JWT; only the payload segment matters for subject decoding.
const oauthToken = (claims: Record<string, unknown>) =>
  ["e30", Buffer.from(JSON.stringify(claims)).toString("base64url"), "sig"].join(".");
const authState = () =>
  json({ code: 0, data: { state: "state", authUrl: "https://www.codebuddy.cn/login" } });
const token = () =>
  json({
    code: 0,
    data: { accessToken: "new-access", refreshToken: "new-refresh", expiresIn: 3600 },
  });
const accounts = (profile: Record<string, unknown> = {}) =>
  json({
    code: 0,
    data: {
      accounts: [
        { uid: "user", email: "user@example.com", nickname: "User", lastLogin: true, ...profile },
      ],
    },
  });
const current: CodebuddyOAuthCredentials = {
  type: "oauth",
  access: "old-access",
  refresh: "old-refresh",
  expires: 1,
  userId: "user",
  uid: "user",
  email: "user@example.com",
  nickname: "User",
  enterpriseId: "old-enterprise",
  enterpriseName: "Old enterprise",
  departmentFullName: "Old department",
};

function interaction(signal?: AbortSignal): AuthInteraction {
  return { signal, notify: vi.fn(), prompt: vi.fn() };
}

function stalled(_url: unknown, init?: RequestInit): Promise<Response> {
  return new Promise((_resolve, reject) => {
    const signal = init?.signal;
    if (!signal) throw new Error("Missing abort signal");
    if (signal.aborted) reject(signal.reason);
    else signal.addEventListener("abort", () => reject(signal.reason), { once: true });
  });
}

beforeEach(() => {
  vi.useFakeTimers();
  // Native AbortSignal.timeout does not use Vitest's fake clock.
  vi.spyOn(AbortSignal, "timeout").mockImplementation((ms) => {
    const controller = new AbortController();
    setTimeout(() => controller.abort(new DOMException("Timed out", "TimeoutError")), ms);
    return controller.signal;
  });
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe("CodeBuddy HTTP cancellation", () => {
  it("aborts a stalled request after the per-request timeout", async () => {
    vi.stubGlobal("fetch", vi.fn(stalled));
    const result = expect(requestJson("https://example.com")).rejects.toMatchObject({
      name: "TimeoutError",
    });
    await vi.advanceTimersByTimeAsync(HTTP_TIMEOUT_MS);
    await result;
  });

  it("keeps the timeout active while reading the response body", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: unknown, init?: RequestInit) => {
        const response = new Response();
        vi.spyOn(response, "text").mockImplementation(async () => {
          await stalled(_url, init);
          return "";
        });
        return response;
      }),
    );
    const result = expect(requestJson("https://example.com")).rejects.toMatchObject({
      name: "TimeoutError",
    });
    await vi.advanceTimersByTimeAsync(HTTP_TIMEOUT_MS);
    await result;
  });

  it("honors caller cancellation without trying a fallback host", async () => {
    const controller = new AbortController();
    const fetch = vi.fn(stalled);
    vi.stubGlobal("fetch", fetch);
    const result = expect(
      tryEach(
        ["https://one.example", "https://two.example"],
        (url) => requestJson(url, { signal: controller.signal }),
        controller.signal,
      ),
    ).rejects.toMatchObject({ name: "AbortError" });
    controller.abort();
    await result;
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("preserves HTTP status for retry classification", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => json({ message: "denied" }, 403)),
    );
    await expect(requestJson("https://example.com")).rejects.toEqual(new HttpError(403, "denied"));
  });
});

describe("CodeBuddy login polling", () => {
  it("requests the auth state with the CLI's uppercase platform value", async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(authState())
      .mockResolvedValueOnce(
        json({ data: { accessToken: "access", refreshToken: "refresh", expiresIn: 3600 } }),
      )
      .mockResolvedValueOnce(accounts());
    vi.stubGlobal("fetch", fetch);
    const pending = loginCodebuddy(interaction());
    await vi.advanceTimersByTimeAsync(0);
    await pending;
    const url = new URL(String(fetch.mock.calls[0][0]));
    // `product.json` declares platform "CLI"; the CLI sends it verbatim.
    expect(url.searchParams.get("platform")).toBe("CLI");
  });

  it.each([
    [{ code: 12345, message: "Authorization rejected" }, "Authorization rejected"],
    [{ code: 0, data: {} }, "missing accessToken"],
    [{ data: {} }, "missing accessToken"],
  ])("fails immediately for terminal response %j", async (payload, message) => {
    const fetch = vi.fn().mockResolvedValueOnce(authState()).mockResolvedValueOnce(json(payload));
    vi.stubGlobal("fetch", fetch);
    await expect(loginCodebuddy(interaction())).rejects.toThrow(message);
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it.each([401, 403])("does not retry HTTP %i", async (status) => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(authState())
      .mockResolvedValueOnce(json({ message: "denied" }, status));
    vi.stubGlobal("fetch", fetch);
    await expect(loginCodebuddy(interaction())).rejects.toThrow(`HTTP ${status}`);
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it.each(["pending", "http-pending", "network", "server"])(
    "retries %s then accepts a usable token without a code",
    async (kind) => {
      const fetch = vi.fn().mockResolvedValueOnce(authState());
      if (kind === "network") fetch.mockRejectedValueOnce(new TypeError("fetch failed"));
      else if (kind === "http-pending") fetch.mockResolvedValueOnce(json({ code: "11217" }, 400));
      else
        fetch.mockResolvedValueOnce(kind === "pending" ? json({ code: "11217" }) : json({}, 503));
      fetch
        .mockResolvedValueOnce(
          json({ data: { accessToken: "access", refreshToken: "refresh", expiresIn: 3600 } }),
        )
        .mockResolvedValueOnce(accounts());
      vi.stubGlobal("fetch", fetch);
      const result = loginCodebuddy(interaction());
      await vi.advanceTimersByTimeAsync(POLL_INTERVAL_MS);
      await expect(result).resolves.toMatchObject({
        access: "access",
        refresh: "refresh",
        userId: "user",
      });
      expect(fetch).toHaveBeenCalledTimes(4);
    },
  );

  it("does not retry invalid JSON", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(authState()).mockResolvedValueOnce(new Response("not JSON")),
    );
    await expect(loginCodebuddy(interaction())).rejects.toThrow("Invalid JSON response");
  });

  it("enforces the total deadline even when token requests stall", async () => {
    const fetch = vi.fn(stalled).mockResolvedValueOnce(authState());
    vi.stubGlobal("fetch", fetch);
    const result = expect(loginCodebuddy(interaction())).rejects.toThrow("authorization timed out");
    await vi.advanceTimersByTimeAsync(POLL_TIMEOUT_MS);
    await result;
  });

  it("cancels an in-flight poll immediately", async () => {
    const controller = new AbortController();
    const fetch = vi.fn(stalled).mockResolvedValueOnce(authState());
    vi.stubGlobal("fetch", fetch);
    const result = expect(loginCodebuddy(interaction(controller.signal))).rejects.toThrow(
      "authorization cancelled",
    );
    await vi.advanceTimersByTimeAsync(0);
    controller.abort();
    await result;
    expect(fetch).toHaveBeenCalledTimes(2);
  });
});

describe("CodeBuddy refreshed account identity", () => {
  it("replaces complete but stale enterprise metadata", async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(token())
      .mockResolvedValueOnce(
        accounts({
          enterpriseId: "new-enterprise",
          enterpriseName: "New enterprise",
          departmentFullName: "New department",
        }),
      );
    vi.stubGlobal("fetch", fetch);
    const result = await refreshCodebuddyCredentials(current);
    expect(result).toMatchObject({
      access: "new-access",
      refresh: "new-refresh",
      enterpriseId: "new-enterprise",
      enterpriseName: "New enterprise",
      departmentFullName: "New department",
    });
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it("sends X-User-Id on the refresh request like every other builder", async () => {
    const fetch = vi.fn().mockResolvedValueOnce(token()).mockResolvedValueOnce(accounts());
    vi.stubGlobal("fetch", fetch);
    await refreshCodebuddyCredentials(current);
    const headers = new Headers(fetch.mock.calls[0][1]?.headers);
    expect(headers.get("x-user-id")).toBe("user");
    expect(headers.get("x-refresh-token")).toBe("old-refresh");
  });

  it("falls back to the anonymous identity when the credential has no subject", async () => {
    const anonymous = {
      ...current,
      access: oauthToken({}),
      userId: undefined,
      uid: undefined,
    };
    const fetch = vi.fn().mockResolvedValueOnce(token());
    vi.stubGlobal("fetch", fetch);
    await refreshCodebuddyCredentials(anonymous);
    expect(new Headers(fetch.mock.calls[0][1]?.headers).get("x-user-id")).toBe("anonymous");
  });

  it("clears enterprise headers after switching to a personal account", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce(token()).mockResolvedValueOnce(accounts()),
    );
    const result = await refreshCodebuddyCredentials(current);
    const auth = codebuddyCredentialsToAuth(result);
    expect(result.enterpriseId).toBeUndefined();
    expect(result.enterpriseName).toBeUndefined();
    expect(auth.headers).not.toHaveProperty("X-Enterprise-Id");
    expect(auth.headers).not.toHaveProperty("X-Department-Info");
  });

  it("forwards enterprise headers when the credential carries them", () => {
    const auth = codebuddyCredentialsToAuth(current);
    expect(current.enterpriseId).toBe("old-enterprise");
    expect(auth.headers).toMatchObject({
      "X-Enterprise-Id": "old-enterprise",
      "X-Tenant-Id": "old-enterprise",
      "X-Department-Info": "Old department",
    });
  });

  it("sends a usable X-User-Id without an enterprise identity", () => {
    const auth = codebuddyCredentialsToAuth({
      ...current,
      access: "ck_opaque.token",
      userId: undefined,
      uid: undefined,
      email: undefined,
      nickname: undefined,
    });
    expect(auth.headers).toMatchObject({ "X-User-Id": "anonymous" });
  });

  it("preserves rotated tokens and old metadata if profile lookup fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(token()).mockResolvedValue(json({}, 503)));
    await expect(refreshCodebuddyCredentials(current)).resolves.toMatchObject({
      access: "new-access",
      refresh: "new-refresh",
      enterpriseId: "old-enterprise",
    });
  });

  it("preserves rotated tokens if cancellation arrives during profile lookup", async () => {
    const controller = new AbortController();
    vi.stubGlobal("fetch", vi.fn(stalled).mockResolvedValueOnce(token()));
    const result = refreshCodebuddyCredentials(current, controller.signal);
    await vi.advanceTimersByTimeAsync(0);
    controller.abort();
    await expect(result).resolves.toMatchObject({ access: "new-access", refresh: "new-refresh" });
  });
});
