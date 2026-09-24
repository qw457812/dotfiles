// Golden checks for the websearch mirror. Ports the assertions of OpenCode
// v2's packages/core/test/websearch.test.ts (selection: failover, cooldowns,
// Retry-After sizing, shared cooldowns) and tool-websearch.test.ts (tool-level
// error messages, all-cooling behavior) onto the mirror's architecture:
// selection-level cases use in-memory fake providers (v2's TestWebSearch
// equivalent), tool-level cases stub global fetch and run the real tool.
//
// Run: node private_dot_pi/private_agent/extensions/tests/websearch-golden.mjs
//
// The parent runs both env groups ("random" and forced "tavily") in child
// processes because the selection is cached per module load.
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { check, equal, loadTs, summary } from "./helpers.mjs";

const selection = await loadTs("../websearch/selection.ts");
const { createWebSearchService: createService } = selection;
const { HttpCallError } = await loadTs("../websearch/providers/types.ts");
const activate = (await loadTs("../websearch/index.ts")).default;

const sleep = (ms) => new Promise((resolve_) => setTimeout(resolve_, ms));
const result = (id) => [{ url: `https://${id}.example/`, title: id, content: "hit" }];

/** v2's TestWebSearch equivalent: a provider with scripted behavior + call log. */
function fakeProvider(id, state) {
  return {
    id,
    label: id,
    async execute(input) {
      state.calls.push(input.query);
      if (typeof state.mode === "function") return state.mode(input, state.calls.length);
      if (state.mode instanceof Error) throw state.mode;
      return result(id);
    },
  };
}

const state = () => ({ calls: [], mode: undefined });
const rateLimited = (retryAfter) => new HttpCallError("rate limited", 429, retryAfter);

function quietErrors(fn) {
  const original = console.error;
  console.error = () => {};
  return fn().finally(() => {
    console.error = original;
  });
}

/** Activate the tool with a stub ExtensionAPI and a scripted fetch. */
function activateTool(fetchImpl) {
  const entries = [];
  let tool;
  const pi = {
    on() {},
    registerTool(definition) {
      tool = definition;
    },
    appendEntry(customType, data) {
      entries.push({ customType, data });
    },
  };
  activate(pi);
  const originalFetch = globalThis.fetch;
  let fetchCalls = [];
  globalThis.fetch = async (url) => {
    fetchCalls.push(String(url));
    return fetchImpl(String(url), fetchCalls.length);
  };
  const restore = () => {
    globalThis.fetch = originalFetch;
  };
  const run = (query, signal) =>
    tool.execute("call-1", { query }, signal, undefined, {
      sessionManager: { getSessionId: () => "golden-session" },
    });
  return { run, entries, fetchCalls: () => fetchCalls, restore };
}

// ---------------------------------------------------------------------------
// Selection-level cases (random routing)
// ---------------------------------------------------------------------------

async function randomSelectionCases() {
  // websearch.test.ts: "fails over on rate limits with random and keeps the
  // replacement after cooldown" (timing adapted: Retry-After "1" instead of
  // TestClock adjustments).
  {
    const exa = state();
    const parallel = state();
    const svc = createService([fakeProvider("exa", exa), fakeProvider("parallel", parallel)]);
    svc.restoreAffinity("s1", "exa");
    const affinityLog = [];
    const onAffinityChange = (id) => affinityLog.push(id);
    const opts = { sessionID: "s1", onAffinityChange };

    const first = await svc.query({ query: "first" }, opts);
    equal("failover: sticky first pick", first.provider, "exa");
    equal("failover: single attempt on success", first.attempts, 1);

    exa.mode = rateLimited("1");
    const progress = [];
    const retry = await svc.query(
      { query: "retry" },
      {
        sessionID: "s1",
        onProvider: (id) => progress.push(id),
        onAffinityChange,
      },
    );
    equal("failover: replacement serves the query", retry.provider, "parallel");
    equal("failover: counted the limited attempt", retry.attempts, 2);
    check(
      "failover: progress is [limited, replacement]",
      JSON.stringify(progress) === '["exa","parallel"]',
      progress,
    );
    equal("failover: limited provider called twice", exa.calls.length, 2);
    check(
      "failover: replacement called once",
      JSON.stringify(parallel.calls) === '["retry"]',
      parallel.calls,
    );

    const cooling = await svc.query({ query: "cooling" }, opts);
    equal("cooldown: limited provider not retried while cooling", cooling.provider, "parallel");
    equal("cooldown: limited call count unchanged", exa.calls.length, 2);

    exa.mode = undefined;
    await sleep(1200);
    const sticky = await svc.query({ query: "still sticky" }, opts);
    equal("sticky: keeps the replacement after cooldown expires", sticky.provider, "parallel");

    parallel.mode = rateLimited("1");
    const recovered = await svc.query({ query: "recovered" }, opts);
    equal("failback: returns to the recovered provider", recovered.provider, "exa");
    equal("failback: counted the limited attempt", recovered.attempts, 2);
    // Session-entry parity (ledger: "Session entries exceed v2"): one entry
    // per real affinity change (the failover and the failback), none for
    // sticky hits or restored affinity.
    check(
      "affinity changes emit one entry each",
      JSON.stringify(affinityLog) === '["parallel","exa"]',
      affinityLog,
    );
  }

  // websearch.test.ts: "fails promptly when all providers are cooling down
  // without asking for a provider" — both queries fail with the rate limit
  // error and no provider is called more than once.
  {
    const exa = state();
    const parallel = state();
    const tavily = state();
    const rate = { mode: rateLimited("120") };
    Object.assign(exa, rate);
    Object.assign(parallel, rate);
    Object.assign(tavily, rate);
    const svc = createService([
      fakeProvider("exa", exa),
      fakeProvider("parallel", parallel),
      fakeProvider("tavily", tavily),
    ]);

    let first;
    await svc.query({ query: "limited" }, { sessionID: "s1" }).catch((err) => (first = err));
    check(
      "all cooling: first query fails with the 429",
      first instanceof HttpCallError && first.status === 429,
      String(first),
    );
    check(
      "all cooling: every provider tried once",
      [exa, parallel, tavily].every((s) => s.calls.length === 1),
      [exa.calls.length, parallel.calls.length, tavily.calls.length],
    );

    let second;
    await svc.query({ query: "still limited" }, { sessionID: "s2" }).catch((err) => (second = err));
    check(
      "all cooling: later query also fails with the 429",
      second instanceof HttpCallError && second.status === 429,
      String(second),
    );
    check(
      "all cooling: no provider retried on the later query",
      [exa, parallel, tavily].every((s) => s.calls.length === 1),
      [exa.calls.length, parallel.calls.length, tavily.calls.length],
    );
  }

  // websearch.test.ts: "tries each provider only once per query even with a
  // zero cooldown"
  {
    const exa = state();
    const parallel = state();
    exa.mode = rateLimited("0");
    parallel.mode = rateLimited("0");
    const svc = createService([fakeProvider("exa", exa), fakeProvider("parallel", parallel)]);
    let err;
    await svc.query({ query: "limited" }, { sessionID: "s1" }).catch((e) => (err = e));
    check(
      "zero cooldown: one attempt per provider",
      err instanceof HttpCallError && exa.calls.length === 1 && parallel.calls.length === 1,
      {
        message: String(err),
        exa: exa.calls.length,
        parallel: parallel.calls.length,
      },
    );
  }

  // websearch.test.ts: "respects Retry-After %j and recovers after cooldown"
  // (the 60s/120s fallback sizes are asserted as "still cooling", since the
  // mirror has no TestClock; the parse paths all recover in bounded time).
  const futureDate = new Date(Date.now() + 2500).toUTCString();
  for (const [label, header, recoveryMs] of [
    ["seconds", "1", 1200],
    ["HTTP-date", futureDate, 3500],
    ["missing", undefined, null],
    ["invalid", "invalid", null],
    ["empty", "", null],
    ["negative", "-1", null],
    ["large", "120", null],
  ]) {
    const exa = state();
    exa.mode = rateLimited(header);
    const svc = createService([fakeProvider("exa", exa)]);

    let limited;
    await svc.query({ query: "limited" }, { sessionID: "s1" }).catch((e) => (limited = e));
    check(
      `Retry-After ${label}: fails with the 429`,
      limited instanceof HttpCallError && limited.status === 429,
      String(limited),
    );

    exa.mode = undefined;
    let early;
    await svc.query({ query: "early" }, { sessionID: "s1" }).catch((e) => (early = e));
    check(
      `Retry-After ${label}: still cooling immediately after`,
      early instanceof HttpCallError && early.status === 429 && exa.calls.length === 1,
      { message: String(early), calls: exa.calls.length },
    );

    if (recoveryMs !== null) {
      await sleep(recoveryMs);
      const recovered = await svc.query({ query: "recovered" }, { sessionID: "s1" });
      equal(`Retry-After ${label}: recovers after the cooldown`, recovered.provider, "exa");
      equal(`Retry-After ${label}: retried after recovery`, exa.calls.length, 2);
    }
  }

  // v2 parity guard: every registered provider joins random routing
  // regardless of credentials (requiresApiKey was removed 2026-09-24), and
  // each session emits exactly one affinity entry for its initial pick.
  {
    delete process.env.TAVILY_API_KEY;
    const picked = new Set();
    let badAffinity = 0;
    for (let i = 0; i < 200; i++) {
      const states = { exa: state(), parallel: state(), firecrawl: state(), tavily: state() };
      const svc = createService(Object.keys(states).map((id) => fakeProvider(id, states[id])));
      let affinities = 0;
      const out = await svc.query(
        { query: "q" },
        { sessionID: `s${i}`, onAffinityChange: () => affinities++ },
      );
      picked.add(out.provider);
      if (affinities !== 1) badAffinity++;
    }
    equal(
      "all providers join keyless random routing",
      [...picked].sort().join(","),
      "exa,firecrawl,parallel,tavily",
    );
    equal("one affinity entry per session", badAffinity, 0);
  }

  // websearch.test.ts: "shares cooldowns without sending a peer back to the
  // rate-limited provider"
  {
    const exa = state();
    const parallel = state();
    exa.mode = rateLimited("120");
    const svc = createService([fakeProvider("exa", exa), fakeProvider("parallel", parallel)]);
    svc.restoreAffinity("s1", "exa");
    const first = await svc.query({ query: "first" }, { sessionID: "s1" });
    equal("shared cooldowns: session fails over", first.provider, "parallel");
    const peer = await svc.query({ query: "peer" }, { sessionID: "s2" });
    equal("shared cooldowns: peer avoids the cooling provider", peer.provider, "parallel");
    equal("shared cooldowns: rate-limited provider called once", exa.calls.length, 1);
  }
}

// ---------------------------------------------------------------------------
// Tool-level cases (random routing)
// ---------------------------------------------------------------------------

async function randomToolCases() {
  // tool-websearch.test.ts: "does not reopen consent when all automatic
  // providers are cooling down" — both the first and the later query surface
  // "Web search rate limited (HTTP 429)", and every provider is contacted at
  // most once.
  delete process.env.TAVILY_API_KEY;
  const tool = activateTool(
    () => new Response(null, { status: 429, headers: { "Retry-After": "120" } }),
  );
  try {
    for (const query of ["first", "cooling"]) {
      let err;
      await quietErrors(() => tool.run(query).catch((e) => (err = e)));
      equal(
        `tool all-cooling (${query}): rate limited message`,
        err?.message,
        "Web search rate limited (HTTP 429)",
      );
    }
    const hosts = new Set(tool.fetchCalls().map((url) => new URL(url).host));
    equal("tool all-cooling: one attempt per provider", tool.fetchCalls().length, 4);
    check(
      "tool all-cooling: all four providers attempted",
      [...hosts].sort().join(",") ===
        "api.tavily.com,mcp.exa.ai,mcp.firecrawl.dev,search.parallel.ai",
      [...hosts],
    );
  } finally {
    tool.restore();
  }
}

// ---------------------------------------------------------------------------
// Tool-level cases (forced provider)
// ---------------------------------------------------------------------------

async function forcedToolCases() {
  // tool-websearch.test.ts: "reports safe HTTP failures with the attempted
  // provider" (upstream's exact message table).
  for (const [status, message] of [
    [403, "Web search request failed (HTTP 403)"],
    [429, "Web search rate limited (HTTP 429)"],
    [401, "Web search authentication failed (HTTP 401)"],
  ]) {
    const tool = activateTool(() => new Response(null, { status }));
    try {
      let err;
      await quietErrors(() => tool.run("golden query").catch((e) => (err = e)));
      equal(`tool HTTP ${status}: safe failure message`, err?.message, message);
      check(`tool HTTP ${status}: cause preserved`, err?.cause instanceof HttpCallError);
    } finally {
      tool.restore();
    }
  }

  // v2's fallback message for non-HTTP failures.
  {
    const tool = activateTool(() => {
      throw new Error("boom");
    });
    try {
      let err;
      await quietErrors(() => tool.run("golden query").catch((e) => (err = e)));
      equal(
        "tool network failure: v2 fallback message",
        err?.message,
        "Unable to search the web for golden query",
      );
      equal("tool network failure: cause preserved", err?.cause?.message, "boom");
    } finally {
      tool.restore();
    }
  }

  // Result consumption: structured results become `## [title](url)` markdown.
  {
    const tool = activateTool(
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
    try {
      const out = await tool.run("golden query");
      equal(
        "tool result: markdown content",
        out.content[0].text,
        "## [Example](https://example.com/a)\n\nexample content",
      );
      equal("tool result: details provider", out.details.provider, "tavily");
      equal("tool result: details attempts", out.details.attempts, 1);
      equal("forced selection: no affinity entries", tool.entries.length, 0);
    } finally {
      tool.restore();
    }
  }

  // Empty result set.
  {
    const tool = activateTool(() => new Response(JSON.stringify({ results: [] }), { status: 200 }));
    try {
      const out = await tool.run("golden query");
      equal(
        "tool empty result: placeholder",
        out.content[0].text,
        "No search results found. Please try a different query.",
      );
    } finally {
      tool.restore();
    }
  }

  // Ledger-backed divergence guard ("User cancellation bypasses the error
  // wrap"): a user abort keeps its plain cancelled message, identified by
  // typed identity rather than message text.
  {
    const tool = activateTool(() => {
      throw Object.assign(new Error("The operation was aborted"), { name: "AbortError" });
    });
    try {
      const controller = new AbortController();
      controller.abort();
      let err;
      await tool.run("golden query", controller.signal).catch((e) => (err = e));
      equal("tool cancellation: plain message kept", err?.message, "Tavily request was cancelled");
      equal("tool cancellation: typed identity kept", err?.name, "RequestCancelledError");
    } finally {
      tool.restore();
    }
  }

  // Impersonation guard: a provider error whose message merely ends like a
  // cancellation is not one — it must go through the error wrap. Errors are
  // classified by type, never by message text.
  {
    const tool = activateTool(() => {
      throw new Error("quota was cancelled");
    });
    try {
      let err;
      await tool.run("golden query").catch((e) => (err = e));
      equal(
        "tool spoof: wrapped, not passed through",
        err?.message,
        "Unable to search the web for golden query",
      );
      equal(
        "tool spoof: original message kept as cause",
        err?.cause?.message,
        "quota was cancelled",
      );
    } finally {
      tool.restore();
    }
  }
}

// ---------------------------------------------------------------------------
// Tool-level cases (forced MCP provider)
// ---------------------------------------------------------------------------

async function forcedMcpCases() {
  // Impersonation guard (the remote vector): a JSON-RPC error whose
  // server-controlled message ends with "was cancelled" must go through the
  // error wrap like any other failure.
  {
    const tool = activateTool(
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
    try {
      let err;
      await tool.run("golden query").catch((e) => (err = e));
      equal(
        "mcp rpc spoof: wrapped, not passed through",
        err?.message,
        "Unable to search the web for golden query",
      );
      equal("mcp rpc spoof: cause is McpRpcError", err?.cause?.name, "McpRpcError");
    } finally {
      tool.restore();
    }
  }

  // Same guard for tool-execution errors: the provider rethrows the server's
  // error text verbatim, and that must still be wrapped.
  {
    const tool = activateTool(
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
    try {
      let err;
      await tool.run("golden query").catch((e) => (err = e));
      equal(
        "mcp tool-error spoof: wrapped, not passed through",
        err?.message,
        "Unable to search the web for golden query",
      );
      equal(
        "mcp tool-error spoof: cause keeps server text",
        err?.cause?.message,
        "Search was cancelled",
      );
    } finally {
      tool.restore();
    }
  }

  // Genuine cancellation over MCP keeps its plain message with typed identity.
  {
    const tool = activateTool(() => {
      throw Object.assign(new Error("The operation was aborted"), { name: "AbortError" });
    });
    try {
      const controller = new AbortController();
      controller.abort();
      let err;
      await tool.run("golden query", controller.signal).catch((e) => (err = e));
      equal(
        "mcp cancellation: plain message kept",
        err?.message,
        "MCP request to web_search_exa was cancelled",
      );
      equal("mcp cancellation: typed identity kept", err?.name, "RequestCancelledError");
    } finally {
      tool.restore();
    }
  }
}

// ---------------------------------------------------------------------------
// Orchestration
// ---------------------------------------------------------------------------

const groups = {
  random: async () => {
    await randomSelectionCases();
    await randomToolCases();
  },
  forced: async () => {
    await forcedToolCases();
  },
  "forced-mcp": async () => {
    await forcedMcpCases();
  },
};

const group = process.argv[2];
if (group) {
  await groups[group]();
  process.exit(summary(`websearch golden (${group})`) ? 1 : 0);
} else {
  let failed = 0;
  for (const [name, provider] of [
    ["random", "random"],
    ["forced", "tavily"],
    ["forced-mcp", "exa"],
  ]) {
    const child = spawnSync(process.execPath, [fileURLToPath(import.meta.url), name], {
      stdio: "inherit",
      env: { ...process.env, PI_WEBSEARCH_PROVIDER: provider },
    });
    if (child.status !== 0) failed++;
  }
  console.log(
    failed ? `websearch golden: ${failed} group(s) failed` : "websearch golden: all groups pass",
  );
  process.exit(failed ? 1 : 0);
}
