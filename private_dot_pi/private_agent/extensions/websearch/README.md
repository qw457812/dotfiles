# Pi WebSearch Extension

Adds a `websearch` tool to [pi](https://pi.dev) that searches the internet via five remote providers (Exa, Firecrawl, Parallel, Tavily, TinyFish), mirroring OpenCode **v2**'s websearch architecture ([anomalyco/opencode](https://github.com/anomalyco/opencode/tree/ba06ff9e0bf2dcefbbbc3a1d6094f3572d77c84e), `dev` branch, 2026-10-19 — the default branch that `v2` was merged into and that now ships the 2.x line).

## Setup

```bash
# Optional — each provider works without a key where its free tier allows
export EXA_API_KEY=exa-...           # https://exa.ai
export PARALLEL_API_KEY=...          # https://parallel.ai
export FIRECRAWL_API_KEY=fc-...      # https://firecrawl.dev
export TAVILY_API_KEY=tvly-...       # https://tavily.com
export TINYFISH_API_KEY=sk-...       # https://agent.tinyfish.ai
```

Then start pi — the `websearch` tool is automatically available.

## Providers

| Provider  | Endpoint                               | Auth (env)          | Keyless     |
| --------- | -------------------------------------- | ------------------- | ----------- |
| Exa       | `https://mcp.exa.ai/mcp`               | `EXA_API_KEY`       | yes         |
| Parallel  | `https://search.parallel.ai/mcp`       | `PARALLEL_API_KEY`  | yes         |
| Firecrawl | `https://mcp.firecrawl.dev/v2/mcp`     | `FIRECRAWL_API_KEY` | yes         |
| Tavily    | `https://api.tavily.com/search` (REST) | `TAVILY_API_KEY`    | yes (flaky) |
| TinyFish  | `https://agent.tinyfish.ai/mcp`        | `TINYFISH_API_KEY`  | yes         |

Exa, Parallel, Firecrawl, and TinyFish go through MCP-over-HTTP; Tavily is a plain REST endpoint. All five join random routing regardless of credentials, exactly like v2. Inherited caveat: only 429 triggers cooldown/failover, so a session whose sticky pick fails some other way — e.g. Tavily's flaky keyless tier answering HTTP 503 — fails its searches until the provider recovers; force another provider with `PI_WEBSEARCH_PROVIDER` to sidestep it.

TinyFish's keyless tier is stateless. With `TINYFISH_API_KEY` set, every search first runs the MCP session handshake — `initialize` → `notifications/initialized` → `tools/call` — because the keyed tier rejects a sessionless `tools/call` with HTTP 400 `Missing required Mcp-Session-Id header`. The session is rebuilt for each search and left to expire, as in v2.

Every provider parses its response into structured results (`url` / `title` / `content` / `published`), which the tool formats as markdown for the LLM:

```
## [Title](url)
Published: 2026-01-02T03:04:05.000Z

content...
```

## Provider Selection

Mirrors OpenCode v2's selection model:

| Scenario                                                           | Provider                 |
| ------------------------------------------------------------------ | ------------------------ |
| `PI_WEBSEARCH_PROVIDER=exa\|parallel\|firecrawl\|tavily\|tinyfish` | forced single provider   |
| `PI_WEBSEARCH_PROVIDER=random` or unset                            | random routing (default) |

**Random routing** (default): each session sticks to one provider until it is rate limited. HTTP 429 puts the provider on a cooldown sized by its `Retry-After` header (seconds or HTTP date, fallback 60s), and the query fails over to another available provider. When every provider is cooling down, the call fails with `Web search rate limited (HTTP 429)`.

**Forced selection**: no failover; errors (including 429) surface directly — an HTTP failure surfaces as `Web search request failed (HTTP N)`, a 429 as `Web search rate limited (HTTP 429)`.

Stickiness is session-scoped and persisted through pi's native custom session entries (`websearch.selection`), so `pi --resume` keeps the same provider. It is **not** persisted across sessions — OpenCode v2 additionally persists a global choice via SQLite KV written by its consent dialog; this extension intentionally has no consent flow and no state file.

Exa, OpenCode's own provider rollout flags, and API keys do **not** affect selection — keys are for authentication only.

## Tool Parameters

| Parameter    | Type              | Description                                    |
| ------------ | ----------------- | ---------------------------------------------- |
| `query`      | string (required) | Search query                                   |
| `numResults` | —                 | removed (v2 fixed result counts internally: 8) |

## Output

Results are joined as markdown (`## [title](url)`, `Published:` line, content) and truncated to 2000 lines / 50 KB (pi's built-in limits). When truncated, the full output is saved to a temp file and the LLM is told the path, using pi's bash-tool bracket format:

```
[Showing lines 1-800 of 1200. Full output: /tmp/pi-websearch-XXXX/output.txt]
```

## Architecture

```
websearch/
├── index.ts              # Tool registration, markdown formatting, error wrapping
├── selection.ts          # v2 selection model: random affinity, 429 cooldowns, failover
├── mcp-client.ts         # Generic MCP-over-HTTP client (JSON-RPC 2.0 + SSE parsing, raw + tool-call requests)
├── providers/
│   ├── types.ts          # Shared types (ProviderID, WebSearchResult, HttpCallError)
│   ├── exa.ts             # Exa (MCP web_search_exa; text format parsed)
│   ├── parallel.ts       # Parallel (MCP web_search; structuredContent parsed)
│   ├── firecrawl.ts      # Firecrawl (MCP firecrawl_search; JSON in text)
│   ├── tavily.ts         # Tavily (REST POST /search)
│   └── tinyfish.ts       # TinyFish (MCP search; keyed requests run the session handshake)
├── render.ts             # Custom TUI rendering
└── README.md
```

No local MCP server processes. All calls go to remote endpoints via HTTPS.
No consent dialog, no KV store, no state file — selection is env + memory.

Golden checks (no model calls, assertions ported from upstream `test/websearch.test.ts` and `test/tool-websearch.test.ts`): `npm --prefix private_dot_pi/private_agent test -- websearch`.

## Differences from OpenCode v2's WebSearch

- **No consent flow** — OpenCode asks on first use and persists the choice (KV `websearch:provider`, value `false` disables the tool entirely); this extension never prompts, and disabling just means not loading it
- **No global persistence** — OpenCode remembers a user-chosen provider across sessions in its app SQLite database; this extension's env var is the declarative config and random affinity is process state
- **Session entries exceed v2** — per-session stickiness persists via pi's `CustomEntry` (`websearch.selection`), surviving `--resume`; v2 keeps affinity in memory only
- **No Effect framework** — plain async/await + TypeBox instead of Effect Schema + Layer
- **Extra provider attempts are not retried on non-429 errors** — same as v2: only rate limits fail over
- **User cancellation bypasses the error wrap** — like the webfetch mirror, genuine user aborts keep their plain `... was cancelled` provider message instead of v2's blanket `Unable to search the web for <query>` narrowing (pi abort semantics)
- **User-Agent** — parallel/tavily/firecrawl/tinyfish send `pi/${VERSION}` instead of OpenCode's app useragent; TinyFish's handshake also announces `clientInfo: { name: "pi", version: ... }` where v2 sends `opencode`/`1.0`
- **`MCP-Protocol-Version` is always sent** — the mirror includes the header on every MCP request (spec 2025-06-18 marks it MUST) and echoes the version negotiated in `initialize`, validated against pi's supported list (2025-11-25, 2025-06-18, 2025-03-26, 2024-11-05) exactly as pi's own MCP client does; the stateless providers (Exa, Parallel, Firecrawl) send the latest supported version because they never handshake; v2 sends the header nowhere, including TinyFish's handshake, relying on the spec's 2025-03-26 fallback
- **TinyFish result parsing is fail-fast** — v2 decodes `content[].text` with an Effect schema and silently yields zero results on a shape mismatch; the mirror throws when `results` is missing, matching the other providers' runtime checks
- **Env var prefix** — `PI_WEBSEARCH_PROVIDER` instead of `opencode.jsonc`'s `websearch.provider`
- **MCP client** — TypeBox schema validation + AbortController timeout instead of Effect Schema + `Effect.timeoutOrElse`
- **Truncation notices** — pi's bash-tool bracket format (`[Showing lines X-Y ...]`) instead of OpenCode's `... N lines truncated; full content saved to ...` marker; both use 2000 lines / 50 KB
- **Tool description wording** — v2 says "Search the web using the user's selected search integration" (accurate for its consent/KV selection and integrations UI); this extension has no user-facing selection, so the first sentence is just "Search the web"

## Drift Notes

- Synced to `ba06ff9e0b` (2026-10-19) on `dev`, the default branch `v2` was merged into: 1685 commits since the previous pin, exactly one touching the mirror surface — `86755e1cea` (2026-10-16), which added TinyFish's keyed MCP session handshake and is ported here. `v2` is frozen at `4617210822` (2.0.26) while 2.0.27–2.0.32 ship from `dev`, so the pin moved lines rather than commits
- 2026-10-19 live smoke: TinyFish answered from both tiers (8–10 results per query). Server behaviors confirmed for the golden checks: keyed `initialize` returns `Mcp-Session-Id` (and negotiates protocol 2025-11-25), `notifications/initialized` is acknowledged 204, `tools/call` without a session answers 400 `-32600`, an unknown session answers 404 `-32001`, `DELETE` answers 405
- Direction signals (unmerged, noted only): `websearch-auto` (automatic web search routing), `websearch-limits` (shared and non-fatal web search limits), `websearch-consent-service` (consent prompt dedupe), `websearch-consent-repro` (consent repro), `direct-websearch` (call the web search service directly), `websearch-plugin-wait` (server waits for plugins before answering)
- 2026-09-24 live smoke: keyless Tavily answered successfully (8 results) instead of the historical HTTP 503 → user decision same day: `requiresApiKey` removed and all providers rejoin random routing regardless of credentials (v2 registration restored, ledger entry dropped); the inherited wedge-on-non-429 caveat stays as parity (see Providers above)

## Differences from the previous version of this extension

- Mirrors OpenCode **v2** instead of `e4bd9757a` (dev line)
- Providers: +Firecrawl, +Tavily, +TinyFish (Exa and Parallel were already there); FNV-1a hash A/B routing replaced by v2's random/affinity/cooldown/failover model
- TinyFish keyed requests run the MCP session handshake (`initialize` → `notifications/initialized` → `tools/call`) and present `Mcp-Session-Id`; keyless requests stay a single tools/call
- `numResults` tool parameter removed (fixed at 8 internally, as in v2)
- Results are parsed to structured objects and formatted as markdown instead of passing provider text through verbatim; Parallel now reads `structuredContent` (and no longer sends `session_id`/`model_name`)
- MCP tool errors (`isError`) now throw instead of being returned inline with a prefix
- Truncation notice uses pi's bracket format
