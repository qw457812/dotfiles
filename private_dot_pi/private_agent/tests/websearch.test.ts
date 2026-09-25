// Golden checks for the websearch mirror. Ports the assertions of OpenCode
// v2's packages/core/test/websearch.test.ts (selection: failover, cooldowns,
// Retry-After sizing, shared cooldowns) and tool-websearch.test.ts (tool-level
// error messages, all-cooling behavior) onto the mirror's architecture:
// selection-level cases use in-memory fake providers (v2's TestWebSearch
// equivalent), tool-level cases stub fetch and run the real tool.
//
// Run: npm --prefix private_dot_pi/private_agent test -- websearch
import type { Mock } from "vitest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type {
  ProviderID,
  WebSearchInput,
  WebSearchProvider,
} from "../extensions/websearch/providers/types";

/** Await a promise that must reject, and return the rejection value. */
async function captureError(promise: Promise<unknown>): Promise<any> {
  try {
    await promise;
  } catch (err) {
    return err;
  }
  throw new Error("expected the call to fail, but it resolved");
}

// The selection caches PI_WEBSEARCH_PROVIDER per module load, so every test
// reloads the mirror modules inside a fresh registry under its own env.
async function loadWebsearch(provider: string) {
  vi.stubEnv("PI_WEBSEARCH_PROVIDER", provider);
  vi.resetModules();
  const types = await import("../extensions/websearch/providers/types");
  const selection = await import("../extensions/websearch/selection");
  const index = await import("../extensions/websearch/index");
  return {
    HttpCallError: types.HttpCallError,
    RequestCancelledError: types.RequestCancelledError,
    createWebSearchService: selection.createWebSearchService,
    activate: index.default as unknown as (pi: unknown) => void,
  };
}

type Mods = Awaited<ReturnType<typeof loadWebsearch>>;

// ---------------------------------------------------------------------------
// Fake providers (v2's TestWebSearch equivalent): scripted behavior + call log
// ---------------------------------------------------------------------------

interface FakeState {
  calls: string[];
  mode?: Error;
}

function state(): FakeState {
  return { calls: [] };
}

function fakeProvider(id: ProviderID, providerState: FakeState): WebSearchProvider {
  return {
    id,
    label: id,
    async execute(input: WebSearchInput) {
      providerState.calls.push(input.query);
      if (providerState.mode instanceof Error) throw providerState.mode;
      return [{ url: `https://${id}.example/`, title: id, content: "hit" }];
    },
  };
}

// ---------------------------------------------------------------------------
// Tool harness: stub ExtensionAPI + scripted fetch
// ---------------------------------------------------------------------------

function activateTool(mods: Mods, fetchImpl: (url: string) => Response) {
  const entries: Array<{ customType: string; data: unknown }> = [];
  let tool: any;
  mods.activate({
    on() {},
    registerTool(definition: any) {
      tool = definition;
    },
    appendEntry(customType: string, data: unknown) {
      entries.push({ customType, data });
    },
  });
  vi.spyOn(console, "error").mockImplementation(() => {});
  const fetchMock = vi.fn(fetchImpl);
  vi.stubGlobal("fetch", fetchMock);
  return {
    run: (query: string, signal?: AbortSignal) =>
      tool.execute("call-1", { query }, signal, undefined, {
        sessionManager: { getSessionId: () => "golden-session" },
      }),
    entries,
    fetchMock: fetchMock as Mock<(url: string) => Response>,
  };
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  vi.useRealTimers();
});

// ---------------------------------------------------------------------------
// Selection-level cases (random routing) — test/websearch.test.ts ports
// ---------------------------------------------------------------------------

describe("selection (random routing)", () => {
  let mods: Mods;

  beforeEach(async () => {
    mods = await loadWebsearch("random");
  });

  // "fails over on rate limits with random and keeps the replacement after
  // cooldown" (TestClock adjustments become fake timers).
  it("fails over on rate limits with random and keeps the replacement after cooldown", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(0);
    const exa = state();
    const parallel = state();
    const svc = mods.createWebSearchService([
      fakeProvider("exa", exa),
      fakeProvider("parallel", parallel),
    ]);
    svc.restoreAffinity("s1", "exa");
    const affinityLog: string[] = [];
    const onAffinityChange = (id: string) => affinityLog.push(id);

    const first = await svc.query({ query: "first" }, { sessionID: "s1", onAffinityChange });
    expect(first).toMatchObject({ provider: "exa", attempts: 1 });

    exa.mode = new mods.HttpCallError("rate limited", 429);
    const progress: string[] = [];
    const retry = await svc.query(
      { query: "retry" },
      { sessionID: "s1", onProvider: (id) => progress.push(id), onAffinityChange },
    );
    expect(retry).toMatchObject({ provider: "parallel", attempts: 2 });
    expect(progress).toEqual(["exa", "parallel"]);
    expect(exa.calls).toEqual(["first", "retry"]);
    expect(parallel.calls).toEqual(["retry"]);

    exa.mode = undefined;
    vi.advanceTimersByTime(59_000);
    const cooling = await svc.query({ query: "cooling" }, { sessionID: "s1", onAffinityChange });
    expect(cooling.provider).toBe("parallel");
    expect(exa.calls).toHaveLength(2);

    vi.advanceTimersByTime(1_000);
    const sticky = await svc.query(
      { query: "still sticky" },
      { sessionID: "s1", onAffinityChange },
    );
    expect(sticky.provider).toBe("parallel");

    parallel.mode = new mods.HttpCallError("rate limited", 429);
    const recovered = await svc.query(
      { query: "recovered" },
      { sessionID: "s1", onAffinityChange },
    );
    expect(recovered).toMatchObject({ provider: "exa", attempts: 2 });
    // Session entries (ledger: "Session entries exceed v2"): one per real
    // affinity change — the failover and the failback — none for sticky hits
    // or restored affinity.
    expect(affinityLog).toEqual(["parallel", "exa"]);
  });

  // "fails promptly when all providers are cooling down without asking for a
  // provider": both queries fail with the rate limit, no provider retried.
  it("fails promptly when all providers are cooling down without asking for a provider", async () => {
    const exa = state();
    const parallel = state();
    const tavily = state();
    const rate = new mods.HttpCallError("rate limited", 429, "120");
    exa.mode = parallel.mode = tavily.mode = rate;
    const svc = mods.createWebSearchService([
      fakeProvider("exa", exa),
      fakeProvider("parallel", parallel),
      fakeProvider("tavily", tavily),
    ]);

    const first = await captureError(svc.query({ query: "limited" }, { sessionID: "s1" }));
    expect(first).toBeInstanceOf(mods.HttpCallError);
    expect(first.status).toBe(429);
    expect([exa.calls, parallel.calls, tavily.calls]).toEqual([
      ["limited"],
      ["limited"],
      ["limited"],
    ]);

    const second = await captureError(svc.query({ query: "still limited" }, { sessionID: "s2" }));
    expect(second).toBeInstanceOf(mods.HttpCallError);
    expect(second.status).toBe(429);
    expect([exa.calls, parallel.calls, tavily.calls]).toEqual([
      ["limited"],
      ["limited"],
      ["limited"],
    ]);
  });

  // "tries each provider only once per query even with a zero cooldown"
  it("tries each provider only once per query even with a zero cooldown", async () => {
    const exa = state();
    const parallel = state();
    const rate = new mods.HttpCallError("rate limited", 429, "0");
    exa.mode = parallel.mode = rate;
    const svc = mods.createWebSearchService([
      fakeProvider("exa", exa),
      fakeProvider("parallel", parallel),
    ]);

    const err = await captureError(svc.query({ query: "limited" }, { sessionID: "s1" }));
    expect(err).toBeInstanceOf(mods.HttpCallError);
    expect([exa.calls.length, parallel.calls.length]).toEqual([1, 1]);
  });

  // "respects Retry-After %j and recovers after cooldown" — upstream's exact
  // table, including the HTTP-date case (its TestClock starts at epoch 0, so
  // fake time does the same here).
  const cooldownTable: Array<[string | undefined, number]> = [
    ["120", 120_000],
    ["Thu, 01 Jan 1970 00:02:00 GMT", 120_000],
    [undefined, 60_000],
    ["invalid", 60_000],
    ["", 60_000],
    ["-1", 60_000],
  ];

  it.each(cooldownTable)(
    "respects Retry-After %j and recovers after cooldown",
    async (header, millis) => {
      vi.useFakeTimers();
      vi.setSystemTime(0);
      const exa = state();
      exa.mode = new mods.HttpCallError("rate limited", 429, header);
      const svc = mods.createWebSearchService([fakeProvider("exa", exa)]);

      const limited = await captureError(svc.query({ query: "limited" }, { sessionID: "s1" }));
      expect(limited).toBeInstanceOf(mods.HttpCallError);

      exa.mode = undefined;
      vi.advanceTimersByTime(millis - 1);
      const early = await captureError(svc.query({ query: "early" }, { sessionID: "s1" }));
      expect(early).toBeInstanceOf(mods.HttpCallError);
      expect(exa.calls).toHaveLength(1);

      vi.advanceTimersByTime(1);
      const recovered = await svc.query({ query: "recovered" }, { sessionID: "s1" });
      expect(recovered.provider).toBe("exa");
      expect(exa.calls).toHaveLength(2);
    },
  );

  // v2 parity guard: every registered provider joins random routing regardless
  // of credentials (requiresApiKey was removed 2026-09-24), and each session
  // emits exactly one affinity entry for its initial pick.
  it("includes every provider in random routing regardless of credentials", async () => {
    const picked = new Set<string>();
    let badAffinity = 0;
    for (let i = 0; i < 200; i++) {
      const states: Record<ProviderID, FakeState> = {
        exa: state(),
        parallel: state(),
        firecrawl: state(),
        tavily: state(),
      };
      const svc = mods.createWebSearchService(
        (Object.keys(states) as ProviderID[]).map((id) => fakeProvider(id, states[id])),
      );
      let affinities = 0;
      const out = await svc.query(
        { query: "q" },
        { sessionID: `s${i}`, onAffinityChange: () => affinities++ },
      );
      picked.add(out.provider);
      if (affinities !== 1) badAffinity++;
    }
    expect([...picked].sort()).toEqual(["exa", "firecrawl", "parallel", "tavily"]);
    expect(badAffinity).toBe(0);
  });

  // "shares cooldowns without sending a peer back to the rate-limited provider"
  it("shares cooldowns without sending a peer back to the rate-limited provider", async () => {
    const exa = state();
    const parallel = state();
    exa.mode = new mods.HttpCallError("rate limited", 429, "120");
    const svc = mods.createWebSearchService([
      fakeProvider("exa", exa),
      fakeProvider("parallel", parallel),
    ]);
    svc.restoreAffinity("s1", "exa");

    const first = await svc.query({ query: "first" }, { sessionID: "s1" });
    expect(first.provider).toBe("parallel");
    const peer = await svc.query({ query: "peer" }, { sessionID: "s2" });
    expect(peer.provider).toBe("parallel");
    expect(exa.calls).toEqual(["first"]);
  });
});

// ---------------------------------------------------------------------------
// Tool-level cases (random routing) — tool-websearch.test.ts ports
// ---------------------------------------------------------------------------

describe("tool (random routing)", () => {
  let mods: Mods;

  beforeEach(async () => {
    mods = await loadWebsearch("random");
  });

  // "does not reopen consent when all automatic providers are cooling down":
  // every query surfaces "Web search rate limited (HTTP 429)" and each of the
  // four providers is contacted at most once.
  it("fails every query with the rate limit while all providers are cooling down", async () => {
    const tool = activateTool(
      mods,
      () => new Response(null, { status: 429, headers: { "Retry-After": "120" } }),
    );

    for (const query of ["first", "cooling"]) {
      const err = await captureError(tool.run(query));
      expect(err, `query ${query}`).toBeInstanceOf(Error);
      expect(err.message).toBe("Web search rate limited (HTTP 429)");
    }

    expect(tool.fetchMock).toHaveBeenCalledTimes(4);
    const hosts = tool.fetchMock.mock.calls.map(([url]) => new URL(url).host);
    expect([...new Set(hosts)].sort()).toEqual([
      "api.tavily.com",
      "mcp.exa.ai",
      "mcp.firecrawl.dev",
      "search.parallel.ai",
    ]);
  });
});

// ---------------------------------------------------------------------------
// Tool-level cases (forced provider) — tool-websearch.test.ts ports
// ---------------------------------------------------------------------------

describe("tool (forced provider)", () => {
  let mods: Mods;

  beforeEach(async () => {
    mods = await loadWebsearch("tavily");
  });

  // "reports safe HTTP failures with the attempted provider" (upstream's
  // message table).
  const httpFailures: Array<[number, string]> = [
    [403, "Web search request failed (HTTP 403)"],
    [429, "Web search rate limited (HTTP 429)"],
    [401, "Web search authentication failed (HTTP 401)"],
  ];

  it.each(httpFailures)(
    "reports safe HTTP failures with the attempted provider (HTTP %i)",
    async (status, message) => {
      const tool = activateTool(mods, () => new Response(null, { status }));
      const err = await captureError(tool.run("golden query"));
      expect(err.message).toBe(message);
      expect(err.cause).toBeInstanceOf(mods.HttpCallError);
      expect(tool.fetchMock).toHaveBeenCalledTimes(1);
    },
  );

  it("wraps network failures in v2's fallback message", async () => {
    const tool = activateTool(mods, () => {
      throw new Error("boom");
    });
    const err = await captureError(tool.run("golden query"));
    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause.message).toBe("boom");
  });

  it("formats structured results as markdown", async () => {
    const tool = activateTool(
      mods,
      () =>
        new Response(
          JSON.stringify({
            results: [
              { url: "https://example.com/a", title: "Example", content: "example content" },
            ],
          }),
          { status: 200 },
        ),
    );
    const out = await tool.run("golden query");
    expect(out.content[0].text).toBe("## [Example](https://example.com/a)\n\nexample content");
    expect(out.details).toMatchObject({ provider: "tavily", attempts: 1 });
    expect(tool.entries).toEqual([]);
  });

  it("returns the placeholder for empty results", async () => {
    const tool = activateTool(
      mods,
      () => new Response(JSON.stringify({ results: [] }), { status: 200 }),
    );
    const out = await tool.run("golden query");
    expect(out.content[0].text).toBe("No search results found. Please try a different query.");
  });

  // Ledger-backed divergence guard ("User cancellation bypasses the error
  // wrap"): a user abort keeps its plain cancelled message, identified by
  // typed identity rather than message text.
  it("keeps its plain message for user cancellation", async () => {
    const tool = activateTool(mods, () => {
      throw Object.assign(new Error("The operation was aborted"), { name: "AbortError" });
    });
    const controller = new AbortController();
    controller.abort();
    const err = await captureError(tool.run("golden query", controller.signal));
    expect(err).toBeInstanceOf(mods.RequestCancelledError);
    expect(err.message).toBe("Tavily request was cancelled");
  });

  // Impersonation guard: a provider error whose message merely ends like a
  // cancellation is not one — it must go through the error wrap.
  it("wraps provider errors that merely imitate cancellation", async () => {
    const tool = activateTool(mods, () => {
      throw new Error("quota was cancelled");
    });
    const err = await captureError(tool.run("golden query"));
    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause.message).toBe("quota was cancelled");
  });
});

// ---------------------------------------------------------------------------
// Tool-level cases (forced MCP provider) — the remote impersonation vectors
// ---------------------------------------------------------------------------

describe("tool (forced MCP provider)", () => {
  let mods: Mods;

  beforeEach(async () => {
    mods = await loadWebsearch("exa");
  });

  it("wraps JSON-RPC errors whose message imitates cancellation", async () => {
    const tool = activateTool(
      mods,
      () =>
        new Response(
          JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            error: { code: -32000, message: "Search request was cancelled" },
          }),
          { status: 200 },
        ),
    );
    const err = await captureError(tool.run("golden query"));
    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause.name).toBe("McpRpcError");
    expect(err.cause.code).toBe(-32000);
  });

  it("wraps tool-execution errors whose text imitates cancellation", async () => {
    const tool = activateTool(
      mods,
      () =>
        new Response(
          JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            result: { content: [{ type: "text", text: "Search was cancelled" }], isError: true },
          }),
          { status: 200 },
        ),
    );
    const err = await captureError(tool.run("golden query"));
    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause.message).toBe("Search was cancelled");
  });

  it("keeps its plain message for user cancellation over MCP", async () => {
    const tool = activateTool(mods, () => {
      throw Object.assign(new Error("The operation was aborted"), { name: "AbortError" });
    });
    const controller = new AbortController();
    controller.abort();
    const err = await captureError(tool.run("golden query", controller.signal));
    expect(err).toBeInstanceOf(mods.RequestCancelledError);
    expect(err.message).toBe("MCP request to web_search_exa was cancelled");
  });
});
