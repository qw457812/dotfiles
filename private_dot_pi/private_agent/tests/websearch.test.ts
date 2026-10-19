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
  const mcpClient = await import("../extensions/websearch/mcp-client");
  return {
    HttpCallError: types.HttpCallError,
    RequestCancelledError: types.RequestCancelledError,
    McpTimeoutError: mcpClient.McpTimeoutError,
    MAX_RESPONSE_BYTES: mcpClient.MAX_RESPONSE_BYTES,
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

function activateTool(
  mods: Mods,
  fetchImpl: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
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
    fetchMock: fetchMock as Mock<(url: string, init?: RequestInit) => Response | Promise<Response>>,
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
        tinyfish: state(),
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
    expect([...picked].sort()).toEqual(["exa", "firecrawl", "parallel", "tavily", "tinyfish"]);
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
  // five providers is contacted at most once.
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

    expect(tool.fetchMock).toHaveBeenCalledTimes(5);
    const hosts = tool.fetchMock.mock.calls.map(([url]) => new URL(url).host);
    expect([...new Set(hosts)].sort()).toEqual([
      "agent.tinyfish.ai",
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

  // A 429 whose body is still being read must keep the cancellation/timeout
  // classification: swallowing it as HttpCallError would turn an abort into a
  // rate limit and drive cooldown/failover.
  function hangingRateLimitedBody(signal: AbortSignal | null | undefined) {
    return new Response(
      new ReadableStream({
        start(controller) {
          signal?.addEventListener("abort", () => {
            controller.error(Object.assign(new Error("aborted"), { name: "AbortError" }));
          });
        },
      }),
      { status: 429, headers: { "Retry-After": "120" } },
    );
  }

  it("keeps cancellation while reading a 429 response body", async () => {
    const controller = new AbortController();
    const tool = activateTool(mods, (_url, init) => {
      queueMicrotask(() => controller.abort());
      return hangingRateLimitedBody(init?.signal);
    });

    const err = await captureError(tool.run("golden query", controller.signal));

    expect(err).toBeInstanceOf(mods.RequestCancelledError);
    expect(err.message).toBe("MCP request to web_search_exa was cancelled");
    expect(tool.fetchMock).toHaveBeenCalledTimes(1);
  });

  it("keeps the timeout while reading a 429 response body", async () => {
    vi.useFakeTimers();
    const tool = activateTool(mods, (_url, init) => hangingRateLimitedBody(init?.signal));

    const pending = captureError(tool.run("golden query"));
    await vi.advanceTimersByTimeAsync(25_001);
    const err = await pending;

    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause).toBeInstanceOf(mods.McpTimeoutError);
    expect(tool.fetchMock).toHaveBeenCalledTimes(1);
  });
});

// ---------------------------------------------------------------------------
// Tool-level cases (forced TinyFish provider) — ports the request-sequence
// assertions of v2's `plugins/websearch` test (initialize → initialized →
// tools/call with Mcp-Session-Id) plus the server behaviors observed live on
// 2026-10-19: keyless initialize returns no session, keyed tools/call without
// one answers 400, an unknown session answers 404, the initialized
// notification is acknowledged with 204.
// ---------------------------------------------------------------------------

describe("tool (forced tinyfish provider)", () => {
  let mods: Mods;

  beforeEach(async () => {
    mods = await loadWebsearch("tinyfish");
  });

  interface Scripted {
    status?: number;
    headers?: Record<string, string>;
    body?: string;
  }

  function scriptedFetch(steps: Scripted[]) {
    const calls: Array<{ url: string; init: RequestInit | undefined }> = [];
    const fetchImpl = (url: string, init?: RequestInit) => {
      calls.push({ url, init });
      const step = steps.shift();
      if (!step) throw new Error("unexpected extra request");
      return new Response(step.body ?? null, {
        status: step.status ?? 200,
        headers: step.headers,
      });
    };
    return { fetchImpl, calls };
  }

  const json = (value: unknown) => JSON.stringify(value);

  const initializeResult = json({
    jsonrpc: "2.0",
    id: 1,
    result: {
      protocolVersion: "2025-11-25",
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: "tinyfish", version: "0.1.1" },
    },
  });

  const searchResult = (query: string) =>
    json({
      jsonrpc: "2.0",
      id: 1,
      result: {
        content: [
          {
            type: "text",
            text: json({
              query,
              results: [{ url: "https://example.com/t", title: "Tiny", snippet: "tiny content" }],
            }),
          },
        ],
      },
    });

  it("runs the MCP session handshake for keyed requests", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl, calls } = scriptedFetch([
      { body: initializeResult, headers: { "mcp-session-id": "ses_tinyfish" } },
      { status: 204 },
      { body: searchResult("golden query") },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const out = await tool.run("golden query");

    expect(calls).toHaveLength(3);
    const bodies = calls.map(({ init }) => JSON.parse(String(init?.body)));
    const headers = calls.map(({ init }) => (init?.headers ?? {}) as Record<string, string>);

    expect(bodies[0]).toMatchObject({
      method: "initialize",
      params: { protocolVersion: "2025-11-25", clientInfo: { name: "pi" } },
    });
    expect(headers[0]).toMatchObject({
      "X-API-Key": "tinyfish-secret",
      "MCP-Protocol-Version": "2025-11-25",
    });
    expect(headers[0]["X-TinyFish-Access-Mode"]).toBeUndefined();

    // Notification: no id, and the session id must be carried already.
    expect(bodies[1]).toEqual({ jsonrpc: "2.0", method: "notifications/initialized" });
    expect(headers[1]["Mcp-Session-Id"]).toBe("ses_tinyfish");

    expect(bodies[2]).toMatchObject({
      method: "tools/call",
      params: { name: "search", arguments: { query: "golden query" } },
    });
    expect(headers[2]["Mcp-Session-Id"]).toBe("ses_tinyfish");

    // The server's answer (2025-11-25 in the fixture, as live) is the
    // negotiated version and is what subsequent requests advertise, matching
    // pi's own MCP client (packages/mcp/src/client.ts echoes
    // InitializeResult.protocolVersion via transport.setProtocolVersion).
    // Source: specification/2025-06-18/basic/lifecycle#version-negotiation
    expect(headers[1]["MCP-Protocol-Version"]).toBe("2025-11-25");
    expect(headers[2]["MCP-Protocol-Version"]).toBe("2025-11-25");

    expect(out.content[0].text).toBe("## [Tiny](https://example.com/t)\n\ntiny content");
    expect(out.details).toMatchObject({ provider: "tinyfish", attempts: 1 });
  });

  it("skips the handshake for keyless requests", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "");
    const { fetchImpl, calls } = scriptedFetch([{ body: searchResult("golden query") }]);
    const tool = activateTool(mods, fetchImpl);
    const out = await tool.run("golden query");

    expect(calls).toHaveLength(1);
    const headers = (calls[0].init?.headers ?? {}) as Record<string, string>;
    expect(headers["X-TinyFish-Access-Mode"]).toBe("keyless");
    expect(headers["X-API-Key"]).toBeUndefined();
    expect(headers["Mcp-Session-Id"]).toBeUndefined();
    // No handshake, so nothing was negotiated: advertise the latest version
    // this client supports (the live keyless tier accepts it).
    expect(headers["MCP-Protocol-Version"]).toBe("2025-11-25");
    expect(out.details.provider).toBe("tinyfish");
  });

  // mcp-client returns { text: "", isError: true } for an MCP error that only
  // carries structuredContent; the empty-text shortcut must not swallow it.
  it("propagates MCP tool errors that carry no text", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "");
    const { fetchImpl } = scriptedFetch([
      {
        body: json({
          jsonrpc: "2.0",
          id: 1,
          result: { content: [], isError: true, structuredContent: { results: [] } },
        }),
      },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause.message).toBe("TinyFish search failed");
  });

  it("fails when initialize returns no Mcp-Session-Id", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl, calls } = scriptedFetch([{ body: initializeResult }]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause.message).toBe(
      "TinyFish MCP initialize did not return an Mcp-Session-Id header",
    );
    expect(calls).toHaveLength(1);
  });

  it("fails fast when initialize returns no protocolVersion", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl, calls } = scriptedFetch([
      {
        body: json({ jsonrpc: "2.0", id: 1, result: { capabilities: {} } }),
        headers: { "mcp-session-id": "ses_tinyfish" },
      },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.cause.message).toBe("TinyFish MCP initialize returned no protocolVersion");
    expect(calls).toHaveLength(1);
  });

  // Port of pi's MCP client test "accepts servers that answer with an older
  // protocol version" (packages/mcp/test/client.test.ts).
  it("accepts a server that answers with an older protocol version", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const older = json({
      jsonrpc: "2.0",
      id: 1,
      result: {
        protocolVersion: "2025-06-18",
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "tinyfish", version: "0.1.1" },
      },
    });
    const { fetchImpl, calls } = scriptedFetch([
      { body: older, headers: { "mcp-session-id": "ses_tinyfish" } },
      { status: 204 },
      { body: searchResult("golden query") },
    ]);
    const tool = activateTool(mods, fetchImpl);
    await tool.run("golden query");

    const headers = calls.map(({ init }) => (init?.headers ?? {}) as Record<string, string>);
    expect(headers[1]["MCP-Protocol-Version"]).toBe("2025-06-18");
    expect(headers[2]["MCP-Protocol-Version"]).toBe("2025-06-18");
  });

  it("rejects a protocol version it does not support", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl, calls } = scriptedFetch([
      {
        body: json({
          jsonrpc: "2.0",
          id: 1,
          result: {
            protocolVersion: "1999-01-01",
            capabilities: {},
            serverInfo: { name: "tinyfish", version: "0.1.1" },
          },
        }),
        headers: { "mcp-session-id": "ses_tinyfish" },
      },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.cause.message).toBe(
      "TinyFish MCP server selected unsupported protocol version 1999-01-01",
    );
    // Fails before the initialized notification and the search.
    expect(calls).toHaveLength(1);
  });

  it("surfaces a JSON-RPC error from initialize", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl } = scriptedFetch([
      {
        body: json({
          jsonrpc: "2.0",
          id: 1,
          error: { code: -32602, message: "Unsupported protocol version" },
        }),
      },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.cause.message).toBe("TinyFish MCP initialize failed: Unsupported protocol version");
  });

  it("surfaces a 429 during initialize as a rate limit with Retry-After", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl, calls } = scriptedFetch([
      { status: 429, headers: { "Retry-After": "120" } },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.message).toBe("Web search rate limited (HTTP 429)");
    expect(err.cause).toBeInstanceOf(mods.HttpCallError);
    expect(err.cause.status).toBe(429);
    expect(err.cause.retryAfter).toBe("120");
    expect(calls).toHaveLength(1);
  });

  it("reports keyed searches rejected without a session", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl } = scriptedFetch([
      { body: initializeResult, headers: { "mcp-session-id": "ses_tinyfish" } },
      { status: 204 },
      {
        status: 400,
        body: json({
          jsonrpc: "2.0",
          id: 1,
          error: { code: -32600, message: "Missing required Mcp-Session-Id header" },
        }),
      },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.message).toBe("Web search request failed (HTTP 400)");
  });

  // v2 parity: upstream initializes per search and never retries a 404, so a
  // "Session not found; send a new initialize request" answer surfaces as-is.
  it("does not re-initialize on a 404 session-not-found (v2 parity)", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl, calls } = scriptedFetch([
      { body: initializeResult, headers: { "mcp-session-id": "ses_tinyfish" } },
      { status: 204 },
      {
        status: 404,
        body: json({
          jsonrpc: "2.0",
          id: 1,
          error: { code: -32001, message: "Session not found; send a new initialize request" },
        }),
      },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.message).toBe("Web search request failed (HTTP 404)");
    expect(calls).toHaveLength(3);
  });

  // MCP 2025-06-18 transports: any request may be answered with either plain
  // JSON or an SSE stream, including initialize.
  it("parses an initialize response delivered over SSE", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl, calls } = scriptedFetch([
      {
        body: `event: message\ndata: ${initializeResult}\n\n`,
        headers: { "mcp-session-id": "ses_tinyfish" },
      },
      { status: 204 },
      { body: searchResult("golden query") },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const out = await tool.run("golden query");

    expect(calls).toHaveLength(3);
    expect(out.details.provider).toBe("tinyfish");
  });

  it("fails cleanly when initialize returns unparseable JSON", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    const { fetchImpl } = scriptedFetch([
      { body: "null", headers: { "mcp-session-id": "ses_tinyfish" } },
    ]);
    const tool = activateTool(mods, fetchImpl);
    const err = await captureError(tool.run("golden query"));

    expect(err.cause.message).toBe("TinyFish MCP initialize returned no JSON-RPC payload");
  });

  it("rejects a response body over the 256 KiB cap", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "");
    const tool = activateTool(
      mods,
      () => new Response("x".repeat(mods.MAX_RESPONSE_BYTES + 1), { status: 200 }),
    );
    const err = await captureError(tool.run("golden query"));

    expect(err.cause.message).toBe(`search response exceeded ${mods.MAX_RESPONSE_BYTES} bytes`);
  });

  // The handshake shares one budget (v2's single Effect.timeoutOrElse), so a
  // timeout reports the handshake, not a per-leg "timed out after Nms".
  it("reports the handshake timeout with the shared budget", async () => {
    vi.stubEnv("TINYFISH_API_KEY", "tinyfish-secret");
    vi.useFakeTimers();
    let requests = 0;
    const tool = activateTool(mods, (_url, init) => {
      requests++;
      return new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => {
          reject(Object.assign(new Error("aborted"), { name: "AbortError" }));
        });
      });
    });

    const pending = captureError(tool.run("golden query"));
    await vi.advanceTimersByTimeAsync(25_001);
    const err = await pending;

    expect(err.cause.message).toBe("TinyFish initialize request timed out");
    expect(err.cause.cause).toBeInstanceOf(mods.McpTimeoutError);
    expect(requests).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// Tool-level cases (forced Firecrawl provider) — mcp-client represents an MCP
// error that only carries structuredContent as { text: "", isError: true }.
// Firecrawl checks the flag before the empty-text shortcut; it must still
// surface an actionable message instead of an empty one.
// ---------------------------------------------------------------------------

describe("tool (forced firecrawl provider)", () => {
  let mods: Mods;

  beforeEach(async () => {
    mods = await loadWebsearch("firecrawl");
  });

  it("propagates MCP tool errors that carry no text", async () => {
    const tool = activateTool(
      mods,
      () =>
        new Response(
          JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            result: { content: [], isError: true, structuredContent: { success: false } },
          }),
          { status: 200 },
        ),
    );
    const err = await captureError(tool.run("golden query"));

    expect(err.message).toBe("Unable to search the web for golden query");
    expect(err.cause.message).toBe("Firecrawl search failed");
  });
});
