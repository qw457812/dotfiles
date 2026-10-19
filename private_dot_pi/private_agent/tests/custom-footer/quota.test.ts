import type { ModelRegistry } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("node:fs/promises", () => ({
  readFile: vi.fn(),
  mkdir: vi.fn(),
  writeFile: vi.fn(),
  readdir: vi.fn(),
  stat: vi.fn(),
}));
vi.mock("node:fs", async (importOriginal) => ({
  ...(await importOriginal<typeof import("node:fs")>()),
  createReadStream: vi.fn(),
}));

import { createReadStream } from "node:fs";
import { readFile, readdir, stat, writeFile } from "node:fs/promises";
import { basename } from "node:path";
import { Readable } from "node:stream";

const theme = { fg: (_color: string, text: string) => text };

async function fixture() {
  const { getQuota } = await import("../../extensions/custom-footer/quota.js");
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

const validSynthetic = {
  rollingFiveHourLimit: { max: 100, remaining: 80, nextTickAt: "2030-01-01" },
  weeklyTokenLimit: { percentRemaining: 70, nextRegenAt: "2030-01-01" },
};

describe("custom footer quota validation", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.mocked(readFile).mockReset().mockRejectedValue(new Error("No cache"));
    vi.mocked(writeFile).mockClear();
    vi.stubEnv("SYNTHETIC_API_KEY", "test-token");
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it("hides a response missing Synthetic weekly quota", async () => {
    const f = await fixture();
    f.fetchMock.mockResolvedValue({
      ok: true,
      json: async () => ({
        rollingFiveHourLimit: validSynthetic.rollingFiveHourLimit,
      }),
    });
    f.get("synthetic");
    await vi.waitFor(() => expect(f.requestRender).toHaveBeenCalled());
    expect(() => f.get("synthetic")).not.toThrow();
    expect(f.get("synthetic")).toBeNull();
  });

  it.each([
    ["synthetic", []],
    ["synthetic", 1],
    ["github-copilot", { quota_snapshots: {} }],
    ["zai", { data: { limits: {} } }],
    ["openai-codex", { quota: { rate_limit: {} }, reset: { credits: [null] } }],
    ["kiro", { usageBreakdownList: [null] }],
  ])("hides malformed %s cached quota without interrupting rendering", async (provider, value) => {
    const f = await fixture();
    vi.mocked(readFile).mockResolvedValue(JSON.stringify({ value, updatedAt: Date.now() }));
    f.get(provider as string);
    await vi.waitFor(() => expect(f.requestRender).toHaveBeenCalled());
    expect(() => f.get(provider as string)).not.toThrow();
    expect(f.get(provider as string)).toBeNull();
  });

  it.each([
    null,
    [],
    {},
    { value: validSynthetic },
    { value: validSynthetic, updatedAt: "now" },
    { value: validSynthetic, updatedAt: Date.now() - 3600000 },
    { value: null, updatedAt: Date.now() },
  ])("ignores invalid cache and replaces it with a valid response: %j", async (cached) => {
    const f = await fixture();
    vi.mocked(readFile).mockResolvedValue(JSON.stringify(cached));
    f.fetchMock.mockResolvedValue({ ok: true, json: async () => validSynthetic });
    f.get("synthetic");
    await vi.waitFor(() => expect(f.requestRender).toHaveBeenCalled());
    expect(f.fetchMock).toHaveBeenCalledTimes(1);
    expect(writeFile).toHaveBeenCalledTimes(1);
    expect(f.get("synthetic")).toMatch(/^20\/100\//);
  });

  it("accepts valid cache with extra fields without requesting auth or fetching", async () => {
    const f = await fixture();
    vi.mocked(readFile).mockResolvedValue(
      JSON.stringify({
        value: { ...validSynthetic, unrelated: { anything: true } },
        updatedAt: Date.now(),
      }),
    );
    f.get("synthetic");
    await vi.waitFor(() => expect(f.requestRender).toHaveBeenCalled());
    expect(f.fetchMock).not.toHaveBeenCalled();
    expect(f.get("synthetic")).toMatch(/^20\/100\//);
  });

  it("isolates formatter errors from TUI rendering", async () => {
    const f = await fixture();
    vi.mocked(readFile).mockResolvedValue(
      JSON.stringify({ value: validSynthetic, updatedAt: Date.now() }),
    );
    f.get("synthetic");
    await vi.waitFor(() => expect(f.requestRender).toHaveBeenCalled());
    const { getQuota } = await import("../../extensions/custom-footer/quota.js");
    const render = () =>
      getQuota(
        "synthetic",
        { requestRender: f.requestRender } as unknown as TUI,
        {
          fg: () => {
            throw new Error("Formatter failed");
          },
        },
        f.registry as unknown as ModelRegistry,
      );
    expect(render).not.toThrow();
    expect(render()).toBeNull();
    expect(f.get("synthetic")).toMatch(/^20\/100\//);
  });
});

describe("custom footer quota authentication", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.mocked(readFile).mockReset().mockRejectedValue(new Error("No cache"));
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

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

describe("Firepass daily usage", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.mocked(readFile).mockReset().mockRejectedValue(new Error("No cache"));
    vi.mocked(writeFile).mockReset();
    vi.mocked(readdir).mockReset();
    vi.mocked(stat).mockReset();
    vi.mocked(createReadStream).mockReset();
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  function message(id: string | undefined, timestamp = new Date().toISOString()) {
    return {
      type: "message",
      id,
      timestamp,
      message: {
        role: "assistant",
        provider: "firepass",
        usage: { totalTokens: 100, cost: { total: 0.1 } },
      },
    };
  }

  async function usage(files: Record<string, unknown[]>) {
    vi.mocked(readdir).mockResolvedValue(
      Object.keys(files).map((name) => ({
        name,
        isDirectory: () => false,
        isFile: () => true,
      })) as unknown as Awaited<ReturnType<typeof readdir>>,
    );
    vi.mocked(stat).mockResolvedValue({ mtime: new Date() } as Awaited<ReturnType<typeof stat>>);
    vi.mocked(createReadStream).mockImplementation(
      (path) =>
        Readable.from(
          files[basename(String(path))].map((entry) => `${JSON.stringify(entry)}\n`),
        ) as ReturnType<typeof createReadStream>,
    );
    const f = await fixture();
    f.get("firepass");
    await vi.waitFor(() => expect(f.requestRender).toHaveBeenCalled());
    return JSON.parse(String(vi.mocked(writeFile).mock.calls[0][1])).value;
  }

  it("counts shared fork/branch history once and new requests on every branch", async () => {
    const shared = message("shared");
    const original = message("original");
    expect(
      await usage({
        "original.jsonl": [shared, original],
        "fork.jsonl": [shared, original, message("fork")],
        "branch.jsonl": [shared, message("branch")],
      }),
    ).toEqual({ tokens: 400, cost: 0.4 });
  });

  it("keeps independent requests with the same short ID but different timestamps", async () => {
    const now = Date.now();
    // Use two timestamps on the same local day, including when the test runs near midnight.
    const later = new Date(now + (new Date(now).getHours() < 12 ? 1000 : -1000)).toISOString();
    expect(
      await usage({
        "a.jsonl": [message("same-id", new Date(now).toISOString())],
        "b.jsonl": [message("same-id", later)],
      }),
    ).toEqual({ tokens: 200, cost: 0.2 });
  });

  it("does not deduplicate messages without usable entry IDs", async () => {
    const noId = message(undefined);
    const emptyId = message("");
    expect(await usage({ "a.jsonl": [noId, emptyId], "b.jsonl": [noId, emptyId] })).toEqual({
      tokens: 400,
      cost: 0.4,
    });
  });
});
