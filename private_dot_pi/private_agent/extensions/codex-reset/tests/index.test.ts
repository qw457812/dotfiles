import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { createHash } from "node:crypto";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import lockfile from "proper-lockfile";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import codexReset from "../index.js";

vi.mock("node:fs/promises", () => ({
  mkdir: vi.fn(),
  readFile: vi.fn(),
  rename: vi.fn(),
  rm: vi.fn(),
  writeFile: vi.fn(),
}));
vi.mock("proper-lockfile", () => ({ default: { lock: vi.fn() } }));

const MINUTE = 60_000;
const NOW = Date.parse("2030-01-01T00:00:00Z");
const files = new Map<string, string>();
const locks = new Set<string>();
const accountId = "test-account";

function token(account = accountId) {
  return `header.${Buffer.from(
    JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: account } }),
  ).toString("base64url")}.signature`;
}

type Credit = { id?: string; status?: string; expires_at?: string | null };
type Body = { credit_id: string; redeem_request_id: string };

function credit(id = "expiring", remaining = 4 * MINUTE): Credit {
  return { id, status: "available", expires_at: new Date(NOW + remaining).toISOString() };
}

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status });
}

function hash(value: unknown) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function statePath(account = accountId) {
  return join(getAgentDir(), "codex-reset-state", `${hash(account)}.json`);
}

function state(account = accountId) {
  return JSON.parse(files.get(statePath(account))!);
}

function fixture(credits: Credit[] = [credit()]) {
  const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => unknown>();
  const commands = new Map<
    string,
    { handler: (args: string, ctx: ExtensionCommandContext) => Promise<void> }
  >();
  const notify = vi.fn();
  const confirm = vi.fn().mockResolvedValue(true);
  const getApiKeyForProvider = vi.fn().mockResolvedValue(token());
  const ctx = {
    hasUI: true,
    modelRegistry: { getApiKeyForProvider },
    ui: { notify, confirm },
  } as unknown as ExtensionCommandContext;
  const post = vi.fn(async (_url: string, _init: RequestInit) =>
    response({ code: "reset", windows_reset: 2 }),
  );
  const fetchMock = vi.fn(async (url: string, init: RequestInit) => {
    if (init.method === "POST") return post(url, init);
    if (url.endsWith("/usage"))
      return response({ rate_limit: { primary_window: { used_percent: 0 } } });
    return response({ credits });
  });
  vi.stubGlobal("fetch", fetchMock);
  codexReset({
    on: (name: string, handler: (event: unknown, ctx: ExtensionContext) => unknown) => {
      handlers.set(name, handler);
    },
    registerCommand: (
      name: string,
      command: { handler: (args: string, ctx: ExtensionCommandContext) => Promise<void> },
    ) => {
      commands.set(name, command);
    },
  } as unknown as ExtensionAPI);
  return {
    ctx,
    notify,
    confirm,
    getApiKeyForProvider,
    fetchMock,
    post,
    credits,
    bodies: () => post.mock.calls.map(([, init]) => JSON.parse(String(init.body)) as Body),
    async start() {
      await handlers.get("session_start")!({}, ctx);
      await vi.advanceTimersByTimeAsync(0);
    },
    async stop() {
      await handlers.get("session_shutdown")!({}, ctx);
    },
    command: (args: string) => commands.get("codex-reset")!.handler(args, ctx),
  };
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(NOW);
  files.clear();
  locks.clear();
  vi.mocked(mkdir).mockReset().mockResolvedValue(undefined);
  vi.mocked(readFile)
    .mockReset()
    .mockImplementation(async (path) => {
      const data = files.get(String(path));
      if (data === undefined) throw Object.assign(new Error("Not found"), { code: "ENOENT" });
      return data;
    });
  vi.mocked(writeFile)
    .mockReset()
    .mockImplementation(async (path, data, options) => {
      if (typeof options === "object" && options?.flag === "wx" && files.has(String(path))) {
        throw Object.assign(new Error("Already exists"), { code: "EEXIST" });
      }
      files.set(String(path), String(data));
    });
  vi.mocked(rename)
    .mockReset()
    .mockImplementation(async (from, to) => {
      const data = files.get(String(from));
      if (data === undefined) throw new Error("Missing temporary file");
      files.set(String(to), data);
      files.delete(String(from));
    });
  vi.mocked(rm)
    .mockReset()
    .mockImplementation(async (path) => {
      files.delete(String(path));
    });
  vi.mocked(lockfile.lock)
    .mockReset()
    .mockImplementation(async (path) => {
      if (locks.has(path)) throw Object.assign(new Error("Busy"), { code: "ELOCKED" });
      locks.add(path);
      return async () => {
        locks.delete(path);
      };
    });
});

afterEach(() => {
  vi.clearAllTimers();
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe("automatic Codex reset eligibility", () => {
  it.each([
    [-1, false],
    [0, false],
    [1, true],
    [5 * MINUTE, true],
    [5 * MINUTE + 1, false],
    [60 * MINUTE, false],
  ])("only consumes when 0 < remaining <= 5 minutes: %i ms", async (remaining, expected) => {
    const f = fixture([credit("boundary", remaining)]);
    await f.start();
    expect(f.post).toHaveBeenCalledTimes(expected ? 1 : 0);
    await f.stop();
  });

  it.each([
    { ...credit(), status: "redeemed" },
    { ...credit(), status: "redeeming" },
    { ...credit(), status: undefined },
    { ...credit(), id: undefined },
    { ...credit(), expires_at: undefined },
    { ...credit(), expires_at: null },
    { ...credit(), expires_at: "invalid" },
  ])("never starts consumption for an ineligible credit: %j", async (invalid) => {
    const f = fixture([invalid, credit("not-expiring", 60 * MINUTE)]);
    await f.start();
    expect(f.post).not.toHaveBeenCalled();
    await f.stop();
  });

  it("submits only the earliest eligible ID without requiring usage or confirmation", async () => {
    const f = fixture([
      credit("later", 4 * MINUTE),
      { ...credit("invalid"), expires_at: "invalid" },
      credit("expired", -MINUTE),
      credit("earliest", MINUTE),
      credit("not-expiring", 60 * MINUTE),
    ]);
    await f.start();
    expect(f.bodies()).toEqual([{ credit_id: "earliest", redeem_request_id: expect.any(String) }]);
    expect(f.confirm).not.toHaveBeenCalled();
    expect(f.fetchMock.mock.calls.some(([url]) => url.endsWith("/usage"))).toBe(false);
    expect(f.notify).toHaveBeenCalledWith(
      expect.stringContaining("Automatically consumed"),
      "info",
    );
    await f.stop();
  });

  it("checks every minute and stops on shutdown", async () => {
    const f = fixture([credit("soon", 6 * MINUTE)]);
    await f.start();
    expect(f.post).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.post).toHaveBeenCalledTimes(1);
    await f.stop();
    const calls = f.fetchMock.mock.calls.length;
    await vi.advanceTimersByTimeAsync(10 * MINUTE);
    expect(f.fetchMock).toHaveBeenCalledTimes(calls);
    expect(locks.size).toBe(0);
  });

  it("does not overlap checks and discards credits expiring during GET", async () => {
    const f = fixture([credit("soon", MINUTE)]);
    let resolve!: (value: Response) => void;
    f.fetchMock.mockImplementationOnce(
      () =>
        new Promise<Response>((done) => {
          resolve = done;
        }),
    );
    await f.start();
    await vi.advanceTimersByTimeAsync(2 * MINUTE);
    expect(f.fetchMock).toHaveBeenCalledTimes(1);
    resolve(response({ credits: f.credits }));
    await vi.advanceTimersByTimeAsync(0);
    expect(f.post).not.toHaveBeenCalled();
    await f.stop();
  });

  it("rechecks expiry after persisting the pending ID", async () => {
    const save = vi.mocked(rename).getMockImplementation()!;
    vi.mocked(rename).mockImplementation(async (...args) => {
      await save(...args);
      if (state().attempts.length > 0) vi.setSystemTime(NOW + 5 * MINUTE);
    });
    const f = fixture();
    await f.start();
    expect(f.post).not.toHaveBeenCalled();
    expect(state().attempts[0].status).toBe("pending");
    await f.stop();
  });

  it("aborts in-flight work on shutdown without submitting or notifying", async () => {
    const f = fixture();
    let resolve!: (value: Response) => void;
    f.fetchMock.mockImplementationOnce(
      () =>
        new Promise<Response>((done) => {
          resolve = done;
        }),
    );
    await f.start();
    const stopping = f.stop();
    expect((f.fetchMock.mock.calls[0][1].signal as AbortSignal).aborted).toBe(true);
    resolve(response({ credits: f.credits }));
    await stopping;
    expect(f.post).not.toHaveBeenCalled();
    expect(f.notify).not.toHaveBeenCalled();
    expect(locks.size).toBe(0);
    expect(vi.getTimerCount()).toBe(0);
  });

  it("quietly skips accounts without auth", async () => {
    const f = fixture();
    f.getApiKeyForProvider.mockResolvedValue(undefined);
    await f.start();
    expect(f.fetchMock).not.toHaveBeenCalled();
    expect(f.notify).not.toHaveBeenCalled();
    await f.stop();
  });

  it.each(["print", "json"])("also consumes in %s mode without a UI", async (mode) => {
    const f = fixture();
    Object.assign(f.ctx, { hasUI: false, mode });
    await f.start();
    expect(f.post).toHaveBeenCalledTimes(1);
    expect(f.confirm).not.toHaveBeenCalled();
    await f.stop();
  });
});

describe("account-wide automatic polling cooldown", () => {
  it("limits five staggered Pi instances to one GET per 60 seconds", async () => {
    const instances = Array.from({ length: 5 }, () => fixture([]));
    const backend = instances[0].fetchMock;
    vi.stubGlobal("fetch", backend);
    for (let i = 0; i < instances.length; i++) {
      if (i > 0) await vi.advanceTimersByTimeAsync(10_000);
      await instances[i].start();
    }
    expect(backend).toHaveBeenCalledTimes(1);
    expect(state()).toMatchObject({ lastAutoPollStartedAt: NOW, attempts: [] });
    await vi.advanceTimersByTimeAsync(20_000);
    expect(backend).toHaveBeenCalledTimes(2);
    await vi.advanceTimersByTimeAsync(40_000);
    expect(backend).toHaveBeenCalledTimes(2);
    expect(state().lastAutoPollStartedAt).toBe(NOW + MINUTE);
    await Promise.all(instances.map((instance) => instance.stop()));
    expect(locks.size).toBe(0);
  });

  it.each([
    [MINUTE - 1, 0],
    [MINUTE, 1],
  ])("keeps the cooldown across reloads at %i milliseconds", async (elapsed, expected) => {
    const first = fixture([]);
    await first.start();
    await first.stop();
    vi.setSystemTime(NOW + elapsed);
    const reloaded = fixture([]);
    await reloaded.start();
    expect(reloaded.fetchMock).toHaveBeenCalledTimes(expected);
    await reloaded.stop();
  });

  it("persists the polling slot before GET, including failed requests", async () => {
    const first = fixture([]);
    first.fetchMock.mockImplementationOnce(async () => {
      expect(state().lastAutoPollStartedAt).toBe(NOW);
      throw new Error("Network unavailable");
    });
    await first.start();
    expect(first.notify).toHaveBeenCalledWith(
      expect.stringContaining("Network unavailable"),
      "warning",
    );
    expect(state()).toMatchObject({ lastAutoPollStartedAt: NOW, attempts: [] });
    await first.stop();
    vi.setSystemTime(NOW + 30_000);
    const second = fixture([]);
    await second.start();
    expect(second.fetchMock).not.toHaveBeenCalled();
    await second.stop();
    vi.setSystemTime(NOW + MINUTE);
    const third = fixture([]);
    await third.start();
    expect(third.fetchMock).toHaveBeenCalledTimes(1);
    await third.stop();
  });

  it("does not query if the polling timestamp cannot be persisted", async () => {
    vi.mocked(writeFile).mockRejectedValue(new Error("Disk full"));
    const f = fixture();
    await f.start();
    expect(f.fetchMock).not.toHaveBeenCalled();
    expect(f.post).not.toHaveBeenCalled();
    expect(f.notify).toHaveBeenCalledWith(expect.stringContaining("Disk full"), "warning");
    expect(locks.size).toBe(0);
    await f.stop();
  });

  it("keeps polling cooldowns separate for different accounts", async () => {
    const first = fixture([]);
    await first.start();
    await first.stop();
    const second = fixture([]);
    second.getApiKeyForProvider.mockResolvedValue(token("another-account"));
    await second.start();
    expect(second.fetchMock).toHaveBeenCalledTimes(1);
    expect(state("another-account").lastAutoPollStartedAt).toBe(NOW);
    await second.stop();
  });

  it.each([undefined, null, "123", true, {}])(
    "rejects an invalid lastAutoPollStartedAt instead of resetting it: %j",
    async (lastAutoPollStartedAt) => {
      const raw = JSON.stringify({ accountId, lastAutoPollStartedAt, attempts: [] });
      files.set(statePath(), raw);
      const f = fixture();
      await f.start();
      expect(f.fetchMock).not.toHaveBeenCalled();
      expect(files.get(statePath())).toBe(raw);
      expect(f.notify).toHaveBeenCalledWith(
        expect.stringContaining("Invalid Codex reset state"),
        "warning",
      );
      await f.stop();
    },
  );

  it("allows manual status queries during the automatic polling cooldown", async () => {
    const f = fixture([]);
    await f.start();
    expect(f.fetchMock).toHaveBeenCalledTimes(1);
    await f.command("status");
    expect(f.fetchMock).toHaveBeenCalledTimes(3);
    expect(state().lastAutoPollStartedAt).toBe(NOW);
    await f.stop();
  });

  it("allows manual consumption during the automatic polling cooldown", async () => {
    const f = fixture([credit("manual", 60 * MINUTE)]);
    await f.start();
    expect(f.post).not.toHaveBeenCalled();
    await f.command("consume");
    expect(f.post).toHaveBeenCalledTimes(1);
    expect(f.notify).toHaveBeenCalledWith(expect.stringContaining("Codex reset consumed."), "info");
    await f.stop();
  });
});

describe("durable idempotent consumption", () => {
  it("publishes the exact request ID atomically before dispatch", async () => {
    const f = fixture();
    f.post.mockImplementation(async (_url, init) => {
      expect(state().attempts[0]).toMatchObject({
        creditId: "expiring",
        redeemRequestId: JSON.parse(String(init.body)).redeem_request_id,
        status: "pending",
      });
      expect([...files.keys()].some((path) => path.endsWith(".tmp"))).toBe(false);
      return response({ code: "reset" });
    });
    await f.start();
    expect(state().attempts[0].status).toBe("reset");
    expect(writeFile).toHaveBeenCalledWith(expect.any(String), expect.any(String), {
      flag: "wx",
      mode: 0o600,
    });
    await f.stop();
  });

  it("retries a lost response with the same ID and recognizes already_redeemed as success", async () => {
    const f = fixture();
    f.post
      .mockRejectedValueOnce(new Error("Response lost"))
      .mockResolvedValue(response({ code: "already_redeemed" }));
    await f.start();
    expect(state().attempts[0].status).toBe("pending");
    expect(f.notify).not.toHaveBeenCalledWith(expect.stringContaining("consumed"), "info");
    f.credits[0].status = "redeemed";
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.bodies()).toHaveLength(2);
    expect(f.bodies()[1]).toEqual(f.bodies()[0]);
    expect(state().attempts[0].status).toBe("already_redeemed");
    expect(f.notify).toHaveBeenCalledWith(
      expect.stringContaining("Confirmed previously consumed"),
      "info",
    );
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.post).toHaveBeenCalledTimes(2);
    await f.stop();
  });

  it("resumes the persisted request after a Pi reload", async () => {
    const first = fixture();
    first.post.mockRejectedValue(new Error("Disconnected"));
    await first.start();
    const body = first.bodies()[0];
    await first.stop();
    vi.setSystemTime(NOW + MINUTE);
    const reloaded = fixture();
    await reloaded.start();
    expect(reloaded.bodies()).toEqual([body]);
    await reloaded.stop();
  });

  it("does not replay a successful consume attempt or notify again when the backend list is stale", async () => {
    const f = fixture();
    await f.start();
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.post).toHaveBeenCalledTimes(1);
    expect(f.notify).toHaveBeenCalledTimes(1);
    await f.stop();
    const reloaded = fixture();
    await reloaded.start();
    expect(reloaded.post).not.toHaveBeenCalled();
    expect(reloaded.notify).not.toHaveBeenCalled();
    await reloaded.stop();
  });

  it.each(["reset", "already_redeemed"])(
    "skips successfully consumed credits (%s) in a stale backend list before selecting the next candidate",
    async (code) => {
      const f = fixture([credit("first", 2.1 * MINUTE), credit("second", 2.2 * MINUTE)]);
      f.post.mockResolvedValueOnce(response({ code }));
      await f.start();
      expect(f.bodies().map((body) => body.credit_id)).toEqual(["first"]);
      await vi.advanceTimersByTimeAsync(MINUTE);
      expect(f.bodies().map((body) => body.credit_id)).toEqual(["first", "second"]);
      expect(Date.now()).toBeLessThan(Date.parse(f.credits[1].expires_at!));
      expect(f.bodies()[1].redeem_request_id).not.toBe(f.bodies()[0].redeem_request_id);
      // Backend responses deliberately keep both cards available until expiry.
      expect(f.credits.map((item) => item.status)).toEqual(["available", "available"]);
      await vi.advanceTimersByTimeAsync(2 * MINUTE);
      expect(f.post).toHaveBeenCalledTimes(2);
      expect(f.notify).toHaveBeenCalledTimes(2);
      expect(state().attempts.map((attempt: { status: string }) => attempt.status)).toEqual([
        code,
        "reset",
      ]);
      await f.stop();
    },
  );

  it("creates a new ID for nothing_to_reset on the next eligible check, without false success", async () => {
    const f = fixture();
    f.post.mockResolvedValueOnce(response({ code: "nothing_to_reset" }));
    await f.start();
    expect(state().attempts[0].status).toBe("nothing_to_reset");
    expect(f.notify).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(MINUTE);
    const [first, second] = f.bodies();
    expect(second.credit_id).toBe(first.credit_id);
    expect(second.redeem_request_id).not.toBe(first.redeem_request_id);
    expect(state().attempts[0].status).toBe("reset");
    expect(f.notify).toHaveBeenCalledTimes(1);
    await f.stop();
  });

  it("uses different IDs for different credits", async () => {
    const f = fixture([credit("first", 2 * MINUTE), credit("second", 4 * MINUTE)]);
    await f.start();
    f.credits[0].status = "redeemed";
    await vi.advanceTimersByTimeAsync(MINUTE);
    const [first, second] = f.bodies();
    expect(first.credit_id).toBe("first");
    expect(second.credit_id).toBe("second");
    expect(second.redeem_request_id).not.toBe(first.redeem_request_id);
    await f.stop();
  });

  it("isolates state and request IDs by account", async () => {
    const first = fixture();
    await first.start();
    await first.stop();
    const second = fixture();
    second.getApiKeyForProvider.mockResolvedValue(token("another-account"));
    await second.start();
    expect(second.bodies()[0].redeem_request_id).not.toBe(first.bodies()[0].redeem_request_id);
    expect(state("another-account").accountId).toBe("another-account");
    await second.stop();
  });

  it.each([null, {}, { code: "success" }, { code: "unexpected" }])(
    "keeps an unknown HTTP 200 outcome pending: %j",
    async (payload) => {
      const f = fixture();
      f.post.mockResolvedValueOnce(response(payload));
      await f.start();
      expect(state().attempts[0].status).toBe("pending");
      expect(f.notify).toHaveBeenCalledWith(
        expect.stringContaining("Unknown Codex consumption outcome"),
        "warning",
      );
      await vi.advanceTimersByTimeAsync(MINUTE);
      expect(f.bodies()[1]).toEqual(f.bodies()[0]);
      await f.stop();
    },
  );

  it("reuses the ID after an HTTP error", async () => {
    const f = fixture();
    f.post.mockResolvedValueOnce(response({ error: "temporarily unavailable" }, 503));
    await f.start();
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.bodies()[1]).toEqual(f.bodies()[0]);
    await f.stop();
  });

  it("persists no_credit and ends the poll without a follow-up GET or another consumption", async () => {
    const f = fixture([credit("first", 2 * MINUTE), credit("second", 4 * MINUTE)]);
    f.post.mockResolvedValue(response({ code: "no_credit" }));
    await f.start();
    expect(f.bodies()).toEqual([{ credit_id: "first", redeem_request_id: expect.any(String) }]);
    expect(f.fetchMock.mock.calls.map(([, init]) => init.method)).toEqual(["GET", "POST"]);
    expect(state().attempts[0].status).toBe("no_credit");
    expect(locks.size).toBe(0);
    expect(f.notify).toHaveBeenCalledWith(
      expect.stringContaining("no other credit was used"),
      "warning",
    );
    expect(f.notify).not.toHaveBeenCalledWith(expect.any(String), "info");
    await f.stop();
  });

  it.each(["available", "redeemed", "none"])(
    "requeries on the next poll after no_credit when the original card is %s",
    async (status) => {
      const f = fixture([credit("first", 4 * MINUTE), credit("second", 4.5 * MINUTE)]);
      f.post.mockResolvedValueOnce(response({ code: "no_credit" }));
      await f.start();
      expect(f.fetchMock.mock.calls.map(([, init]) => init.method)).toEqual(["GET", "POST"]);
      expect(state().attempts[0].status).toBe("no_credit");
      const firstAttempt = f.bodies()[0];
      if (status === "redeemed") f.credits[0].status = "redeemed";
      if (status === "none")
        f.credits.forEach((item) => {
          item.status = "redeemed";
        });
      await vi.advanceTimersByTimeAsync(MINUTE);
      expect(f.fetchMock.mock.calls.filter(([, init]) => init.method === "GET")).toHaveLength(2);
      if (status === "none") {
        expect(f.post).toHaveBeenCalledTimes(1);
        expect(state().attempts[0].status).toBe("no_credit");
      } else {
        expect(f.post).toHaveBeenCalledTimes(2);
        expect(f.bodies()[1].credit_id).toBe(status === "available" ? "first" : "second");
        expect(f.bodies()[1].redeem_request_id).not.toBe(firstAttempt.redeem_request_id);
      }
      await f.stop();
    },
  );

  it("prioritizes an uncertain original card over a different earlier-expiring card", async () => {
    const f = fixture();
    f.post.mockRejectedValueOnce(new Error("Response lost"));
    await f.start();
    f.credits.push(credit("different", 2 * MINUTE));
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.bodies()[1]).toEqual(f.bodies()[0]);
    await f.stop();
  });

  it("does not fall back when the pending card disappears from the backend list", async () => {
    const f = fixture();
    f.post.mockRejectedValueOnce(new Error("Response lost"));
    await f.start();
    f.credits.splice(0, 1, credit("different", 2 * MINUTE));
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.post).toHaveBeenCalledTimes(1);
    await f.stop();
  });

  it.each(["expired", "outside-window"])(
    "does not retry a pending card that is %s",
    async (condition) => {
      const f = fixture([credit("pending", condition === "expired" ? 30_000 : 4 * MINUTE)]);
      f.post.mockRejectedValueOnce(new Error("Response lost"));
      await f.start();
      if (condition === "outside-window")
        f.credits[0].expires_at = credit("later", 60 * MINUTE).expires_at;
      await vi.advanceTimersByTimeAsync(MINUTE);
      expect(f.post).toHaveBeenCalledTimes(1);
      await f.stop();
    },
  );
});

describe("state and locking safety", () => {
  it("serializes concurrent Pi instances and suppresses duplicate success notifications", async () => {
    const first = fixture();
    const second = fixture();
    await Promise.all([first.start(), second.start()]);
    expect(second.post).toHaveBeenCalledTimes(1);
    expect(first.notify.mock.calls.length + second.notify.mock.calls.length).toBe(1);
    await Promise.all([first.stop(), second.stop()]);
    expect(locks.size).toBe(0);
  });

  it("retains the cross-instance retry cooldown after a failed request", async () => {
    const first = fixture();
    first.post.mockRejectedValue(new Error("Disconnected"));
    await first.start();
    await first.stop();
    const second = fixture();
    await second.start();
    expect(second.post).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(second.bodies()[0]).toEqual(first.bodies()[0]);
    await second.stop();
  });

  it("fails closed before POST when persisting the pending record fails", async () => {
    const write = vi.mocked(writeFile).getMockImplementation()!;
    vi.mocked(writeFile).mockImplementation(async (...args) => {
      if (JSON.parse(String(args[1])).attempts.length > 0) throw new Error("Disk full");
      await write(...args);
    });
    const f = fixture();
    await f.start();
    expect(f.post).not.toHaveBeenCalled();
    expect(f.notify).toHaveBeenCalledWith(expect.stringContaining("Disk full"), "warning");
    expect(locks.size).toBe(0);
    await f.stop();
  });

  it("preserves the pending ID if saving a successful outcome fails", async () => {
    const save = vi.mocked(rename).getMockImplementation()!;
    vi.mocked(rename).mockImplementation(async (...args) => {
      const next = JSON.parse(files.get(String(args[0]))!);
      if (next.attempts[0]?.status === "reset") throw new Error("Write failed");
      await save(...args);
    });
    const f = fixture();
    f.post
      .mockResolvedValueOnce(response({ code: "reset" }))
      .mockResolvedValue(response({ code: "already_redeemed" }));
    await f.start();
    expect(state().attempts[0].status).toBe("pending");
    expect([...files.keys()].some((path) => path.endsWith(".tmp"))).toBe(false);
    await vi.advanceTimersByTimeAsync(MINUTE);
    expect(f.bodies()[1]).toEqual(f.bodies()[0]);
    expect(state().attempts[0].status).toBe("already_redeemed");
    await f.stop();
  });

  it.each([
    "not json",
    "null",
    JSON.stringify({ accountId: "wrong", lastAutoPollStartedAt: 0, attempts: [] }),
    JSON.stringify({ accountId, lastAutoPollStartedAt: 0, attempts: [{ status: "pending" }] }),
  ])("never replaces invalid persisted state: %s", async (raw) => {
    files.set(statePath(), raw);
    const f = fixture();
    await f.start();
    expect(f.post).not.toHaveBeenCalled();
    expect(files.get(statePath())).toBe(raw);
    await f.stop();
  });

  it("aborts work if the account lock is compromised", async () => {
    const f = fixture();
    f.fetchMock.mockImplementationOnce(async (_url, init) => {
      vi.mocked(lockfile.lock).mock.calls[0][1]!.onCompromised!(new Error("Lock lost"));
      expect(init.signal!.aborted).toBe(true);
      return response({ credits: f.credits });
    });
    await f.start();
    expect(f.post).not.toHaveBeenCalled();
    expect(f.notify).toHaveBeenCalledWith(expect.stringContaining("Lock lost"), "warning");
    await f.stop();
  });
});

describe("manual Codex consumption", () => {
  it("notifies after confirmed consumption outside the automatic expiry window", async () => {
    const f = fixture([credit("manual", 60 * MINUTE)]);
    await f.command("consume");
    expect(f.confirm).toHaveBeenCalledTimes(1);
    expect(f.confirm).toHaveBeenCalledWith(
      "Consume Codex reset?",
      expect.stringContaining(
        "A successful reset consumes one banked credit and cannot be undone.",
      ),
    );
    expect(f.notify).toHaveBeenCalledWith(expect.stringContaining("Codex reset consumed."), "info");
    expect(f.post).toHaveBeenCalledTimes(1);
  });

  it("manual retry shares the automatic request ID, even if the card is now redeemed", async () => {
    const f = fixture();
    f.post
      .mockRejectedValueOnce(new Error("Response lost"))
      .mockResolvedValue(response({ code: "already_redeemed" }));
    await f.start();
    f.credits[0].status = "redeemed";
    await f.command("consume");
    expect(f.bodies()).toHaveLength(2);
    expect(f.bodies()[1]).toEqual(f.bodies()[0]);
    expect(f.notify).toHaveBeenCalledWith(
      expect.stringContaining("Confirmed previously consumed"),
      "info",
    );
    await f.stop();
  });

  it("automatic retry also shares the manual request ID", async () => {
    const f = fixture();
    f.post.mockRejectedValueOnce(new Error("Response lost"));
    await f.command("consume");
    vi.setSystemTime(NOW + MINUTE);
    await f.start();
    expect(f.bodies()[1]).toEqual(f.bodies()[0]);
    await f.stop();
  });

  it("does not select another card when the default pending card is absent", async () => {
    const f = fixture();
    f.post.mockRejectedValueOnce(new Error("Response lost"));
    await f.command("consume");
    f.credits.splice(0, 1, credit("different"));
    await f.command("consume");
    expect(f.post).toHaveBeenCalledTimes(1);
    expect(f.notify).toHaveBeenCalledWith(
      expect.stringContaining("no other credit was selected"),
      "warning",
    );
  });

  it.each(["nothing_to_reset", "no_credit"])("does not report %s as consumed", async (code) => {
    const f = fixture();
    f.post.mockResolvedValue(response({ code }));
    await f.command("consume");
    expect(f.notify).not.toHaveBeenCalledWith(
      expect.stringContaining("Codex reset consumed."),
      "info",
    );
    expect(f.fetchMock.mock.calls.map(([, init]) => init.method)).toEqual(["GET", "GET", "POST"]);
    expect(state().attempts[0].status).toBe(code);
    expect(locks.size).toBe(0);
  });

  it("revalidates the selected card after confirmation without falling back", async () => {
    const f = fixture();
    f.confirm.mockImplementation(async () => {
      f.credits.splice(0, 1, credit("different"));
      return true;
    });
    await f.command("consume");
    expect(f.post).not.toHaveBeenCalled();
    expect(f.notify).toHaveBeenCalledWith(
      expect.stringContaining("no other credit was used"),
      "info",
    );
  });

  it("refuses a confirmation obtained for a different account", async () => {
    const f = fixture();
    f.confirm.mockImplementation(async () => {
      f.getApiKeyForProvider.mockResolvedValue(token("another"));
      return true;
    });
    await f.command("consume");
    expect(f.post).not.toHaveBeenCalled();
    expect(f.notify).toHaveBeenCalledWith(expect.stringContaining("account changed"), "warning");
  });

  it("preserves dry-run without modifying the state or taking a lock", async () => {
    const f = fixture();
    await f.command("consume --dry-run");
    expect(f.confirm).not.toHaveBeenCalled();
    expect(f.post).not.toHaveBeenCalled();
    expect(writeFile).not.toHaveBeenCalled();
    expect(lockfile.lock).not.toHaveBeenCalled();
    expect(f.notify).toHaveBeenCalledWith(expect.stringContaining("--dry-run"), "info");
  });
});
