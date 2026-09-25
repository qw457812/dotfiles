# Pi WebSearch Extension

Adds a `websearch` tool to [pi](https://pi.dev) that searches the internet via four remote providers (Exa, Firecrawl, Parallel, Tavily), mirroring OpenCode **v2**'s websearch architecture ([anomalyco/opencode](https://github.com/anomalyco/opencode/tree/808588e9b9c1e5c960bd4dcdcd0d0b2c1056ecc5), `v2` branch, 2026-09-24).

## Setup

```bash
# Optional — each provider works without a key where its free tier allows
export EXA_API_KEY=exa-...           # https://exa.ai
export PARALLEL_API_KEY=...          # https://parallel.ai
export FIRECRAWL_API_KEY=fc-...      # https://firecrawl.dev
export TAVILY_API_KEY=tvly-...       # https://tavily.com
```

Then start pi — the `websearch` tool is automatically available.

## Providers

| Provider  | Endpoint                               | Auth (env)          | Keyless     |
| --------- | -------------------------------------- | ------------------- | ----------- |
| Exa       | `https://mcp.exa.ai/mcp`               | `EXA_API_KEY`       | yes         |
| Parallel  | `https://search.parallel.ai/mcp`       | `PARALLEL_API_KEY`  | yes         |
| Firecrawl | `https://mcp.firecrawl.dev/v2/mcp`     | `FIRECRAWL_API_KEY` | yes         |
| Tavily    | `https://api.tavily.com/search` (REST) | `TAVILY_API_KEY`    | yes (flaky) |

Exa, Parallel, and Firecrawl go through MCP-over-HTTP; Tavily is a plain REST endpoint. All four join random routing regardless of credentials, exactly like v2. Inherited caveat: only 429 triggers cooldown/failover, so a session whose sticky pick fails some other way — e.g. Tavily's flaky keyless tier answering HTTP 503 — fails its searches until the provider recovers; force another provider with `PI_WEBSEARCH_PROVIDER` to sidestep it.

Every provider parses its response into structured results (`url` / `title` / `content` / `published`), which the tool formats as markdown for the LLM:

```
## [Title](url)
Published: 2026-01-02T03:04:05.000Z

content...
```

## Provider Selection

Mirrors OpenCode v2's selection model:

| Scenario                                                 | Provider                 |
| -------------------------------------------------------- | ------------------------ |
| `PI_WEBSEARCH_PROVIDER=exa\|parallel\|firecrawl\|tavily` | forced single provider   |
| `PI_WEBSEARCH_PROVIDER=random` or unset                  | random routing (default) |

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
├── mcp-client.ts         # Generic MCP-over-HTTP client (JSON-RPC 2.0 + SSE parsing)
├── providers/
│   ├── types.ts          # Shared types (ProviderID, WebSearchResult, HttpCallError)
│   ├── exa.ts             # Exa (MCP web_search_exa; text format parsed)
│   ├── parallel.ts       # Parallel (MCP web_search; structuredContent parsed)
│   ├── firecrawl.ts      # Firecrawl (MCP firecrawl_search; JSON in text)
│   └── tavily.ts         # Tavily (REST POST /search)
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
- **User-Agent** — parallel/tavily/firecrawl send `pi/${VERSION}` instead of OpenCode's app useragent
- **Env var prefix** — `PI_WEBSEARCH_PROVIDER` instead of `opencode.jsonc`'s `websearch.provider`
- **MCP client** — TypeBox schema validation + AbortController timeout instead of Effect Schema + `Effect.timeoutOrElse`
- **Truncation notices** — pi's bash-tool bracket format (`[Showing lines X-Y ...]`) instead of OpenCode's `... N lines truncated; full content saved to ...` marker; both use 2000 lines / 50 KB
- **No TinyFish provider** — v2 ships it (`agent.tinyfish.ai/mcp`) but its docs omit it, it exists on only one of the two release lines, and it depends on JSON hidden inside MCP text content; revisit if it stabilizes
- **Tool description wording** — v2 says "Search the web using the user's selected search integration" (accurate for its consent/KV selection and integrations UI); this extension has no user-facing selection, so the first sentence is just "Search the web"

## Drift Notes

- Synced to `808588e9b` (2026-09-24): zero drift on `origin/v2` for the mirrored axes since the previous pin — nothing to port
- Direction signals (unmerged, noted only): `websearch-auto` (automatic web search routing), `websearch-limits` (shared and non-fatal web search limits), `websearch-consent-service` (consent prompt dedupe), `direct-websearch` (call the web search service directly)
- 2026-09-24 live smoke: keyless Tavily answered successfully (8 results) instead of the historical HTTP 503 → user decision same day: `requiresApiKey` removed and all providers rejoin random routing regardless of credentials (v2 registration restored, ledger entry dropped); the inherited wedge-on-non-429 caveat stays as parity (see Providers above)

## Differences from the previous version of this extension

- Mirrors OpenCode **v2** instead of `e4bd9757a` (dev line)
- Providers: +Firecrawl, +Tavily (Exa and Parallel were already there); FNV-1a hash A/B routing replaced by v2's random/affinity/cooldown/failover model
- `numResults` tool parameter removed (fixed at 8 internally, as in v2)
- Results are parsed to structured objects and formatted as markdown instead of passing provider text through verbatim; Parallel now reads `structuredContent` (and no longer sends `session_id`/`model_name`)
- MCP tool errors (`isError`) now throw instead of being returned inline with a prefix
- Truncation notice uses pi's bracket format
