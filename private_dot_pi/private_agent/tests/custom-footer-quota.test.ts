import type { ModelRegistry } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("node:fs/promises", () => ({
  readFile: vi.fn(),
  mkdir: vi.fn(),
  writeFile: vi.fn(),
}));

import { readFile } from "node:fs/promises";

const theme = { fg: (_color: string, text: string) => text };

async function fixture() {
  const { getQuota } = await import("../extensions/custom-footer/quota.js");
  const requestRender = vi.fn();
  const registry = {
    getApiKeyForProvider: vi.fn(),
    getProviderAuth: vi.fn(),
  };
  const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ code: 0 }) });
  vi.stubGlobal("fetch", fetchMock);
  return {
    registry,
    fetchMock,
    requestRender,
    get: (provider: string) =>
      getQuota(
        provider,
        { requestRender } as unknown as TUI,
        theme,
        registry as unknown as ModelRegistry,
      ),
  };
}

describe("custom footer quota authentication", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.mocked(readFile).mockReset().mockRejectedValue(new Error("No cache"));
  });
  afterEach(() => vi.unstubAllGlobals());

  it("uses Pi's resolved Codex token instead of reading auth.json", async () => {
    const f = await fixture();
    f.registry.getApiKeyForProvider.mockResolvedValue("refreshed-codex-token");
    f.get("openai-codex");
    await vi.waitFor(() => expect(f.fetchMock).toHaveBeenCalled());
    expect(f.registry.getApiKeyForProvider).toHaveBeenCalledWith("openai-codex");
    expect(f.fetchMock.mock.calls[0][1].headers.Authorization).toBe("Bearer refreshed-codex-token");
    expect(
      vi.mocked(readFile).mock.calls.every(([path]) => !String(path).endsWith("auth.json")),
    ).toBe(true);
  });

  it("uses resolved CodeBuddy token and enterprise header", async () => {
    const f = await fixture();
    f.registry.getProviderAuth.mockResolvedValue({
      auth: { apiKey: "refreshed-codebuddy-token", headers: { "x-enterprise-id": "enterprise" } },
    });
    f.get("codebuddy");
    await vi.waitFor(() => expect(f.fetchMock).toHaveBeenCalled());
    expect(f.registry.getProviderAuth).toHaveBeenCalledWith("codebuddy");
    expect(f.fetchMock.mock.calls[0][1].headers).toMatchObject({
      Authorization: "Bearer refreshed-codebuddy-token",
      "X-Enterprise-Id": "enterprise",
    });
  });

  it("queries current Kiro usage and formats the actual response fields", async () => {
    const f = await fixture();
    f.registry.getApiKeyForProvider.mockImplementation(async () => {
      vi.mocked(readFile).mockResolvedValue(
        JSON.stringify({
          kiro: { region: "us-east-1", access: "stale", profileArn: "test-profile" },
        }),
      );
      return "refreshed-kiro-token";
    });
    const bucket = {
      currentUsage: 0,
      currentUsageWithPrecision: 0.02,
      usageLimit: 50,
      usageLimitWithPrecision: 50,
      nextDateReset: Math.floor(Date.now() / 1000) + 3600,
    };
    f.fetchMock.mockResolvedValue({
      ok: true,
      json: async () => ({
        usageBreakdownList: [bucket],
      }),
    });
    f.get("kiro");
    await vi.waitFor(() => expect(f.requestRender).toHaveBeenCalled());
    expect(f.registry.getApiKeyForProvider).toHaveBeenCalledWith("kiro");
    const url = new URL(f.fetchMock.mock.calls[0][0]);
    expect(url.origin).toBe("https://management.us-east-1.kiro.dev");
    expect(url.pathname).toBe("/Get-Usage-Limits");
    expect(Object.fromEntries(url.searchParams)).toEqual({
      profileArn: "test-profile",
      origin: "KIRO_CLI",
      resourceType: "CREDIT",
      isEmailRequired: "false",
    });
    expect(f.fetchMock.mock.calls[0][1]).toMatchObject({
      method: "GET",
      headers: { Authorization: "Bearer refreshed-kiro-token" },
    });
    expect(f.get("kiro")).toMatch(/^0\.02\/50 \d+[mh]/);
  });

  it.each([{ region: "us-east-1" }, { profileArn: "test-profile" }])(
    "skips Kiro usage when required metadata is missing: %j",
    async (metadata) => {
      const f = await fixture();
      f.registry.getApiKeyForProvider.mockResolvedValue("token");
      vi.mocked(readFile).mockImplementation(async (path) => {
        if (String(path).endsWith("auth.json")) return JSON.stringify({ kiro: metadata });
        throw new Error("No cache");
      });
      expect(f.get("kiro")).toBeNull();
      await vi.waitFor(() =>
        expect(
          vi.mocked(readFile).mock.calls.some(([path]) => String(path).endsWith("auth.json")),
        ).toBe(true),
      );
      expect(f.fetchMock).not.toHaveBeenCalled();
    },
  );

  it("does not fetch CodeBuddy quota when auth resolution fails", async () => {
    const f = await fixture();
    f.registry.getProviderAuth.mockRejectedValue(new Error("Refresh failed"));
    f.get("codebuddy");
    await vi.waitFor(() => expect(f.registry.getProviderAuth).toHaveBeenCalled());
    expect(f.fetchMock).not.toHaveBeenCalled();
  });
});
