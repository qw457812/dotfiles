# Pi WebSearch Extension

Adds a `websearch` tool to [pi](https://pi.dev) that searches the internet via four remote providers (Exa, Firecrawl, Parallel, Tavily), mirroring OpenCode **v2**'s websearch architecture ([anomalyco/opencode](https://github.com/anomalyco/opencode/tree/9c8a63e852722a9bced4a0de1179de58a85dfa20), `v2` branch, 2026-09-23).

## Setup

```bash
# Optional — each provider works without a key where its free tier allows
# (Tavily effectively requires a key; see table below)
export EXA_API_KEY=exa-...           # https://exa.ai
export PARALLEL_API_KEY=...          # https://parallel.ai
export FIRECRAWL_API_KEY=fc-...      # https://firecrawl.dev
export TAVILY_API_KEY=tvly-...       # https://tavily.com
```

Then start pi — the `websearch` tool is automatically available.

## Providers

| Provider  | Endpoint                               | Auth (env)          | Keyless |
| --------- | -------------------------------------- | ------------------- | ------- |
| Exa       | `https://mcp.exa.ai/mcp`               | `EXA_API_KEY`       | yes     |
| Parallel  | `https://search.parallel.ai/mcp`       | `PARALLEL_API_KEY`  | yes     |
| Firecrawl | `https://mcp.firecrawl.dev/v2/mcp`     | `FIRECRAWL_API_KEY` | yes     |
| Tavily    | `https://api.tavily.com/search` (REST) | `TAVILY_API_KEY`    | no      |

Exa, Parallel, and Firecrawl go through MCP-over-HTTP; Tavily is a plain REST endpoint. Tavily is **excluded from random routing when `TAVILY_API_KEY` is unset** — its keyless tier currently answers HTTP 503, and a random pick would wedge a session on a failing provider (only 429 triggers cooldown/failover). Forcing `PI_WEBSEARCH_PROVIDER=tavily` still attempts it.

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

**Forced selection**: no failover; errors (including 429) surface directly — e.g. a keyless Tavily call fails with HTTP 503 ("Keyless Tavily is temporarily unavailable").

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

## Differences from OpenCode v2's WebSearch

- **No consent flow** — OpenCode asks on first use and persists the choice (KV `websearch:provider`, value `false` disables the tool entirely); this extension never prompts, and disabling just means not loading it
- **No global persistence** — OpenCode remembers a user-chosen provider across sessions in its app SQLite database; this extension's env var is the declarative config and random affinity is process state
- **Session entries exceed v2** — per-session stickiness persists via pi's `CustomEntry` (`websearch.selection`), surviving `--resume`; v2 keeps affinity in memory only
- **No Effect framework** — plain async/await + TypeBox instead of Effect Schema + Layer
- **Extra provider attempts are not retried on non-429 errors** — same as v2: only rate limits fail over
- **User-Agent** — parallel/tavily/firecrawl send `pi/${VERSION}` instead of OpenCode's app useragent
- **Env var prefix** — `PI_WEBSEARCH_PROVIDER` instead of `opencode.jsonc`'s `websearch.provider`
- **MCP client** — TypeBox schema validation + AbortController timeout instead of Effect Schema + `Effect.timeoutOrElse`
- **Truncation notices** — pi's bash-tool bracket format (`[Showing lines X-Y ...]`) instead of OpenCode's `... N lines truncated; full content saved to ...` marker; both use 2000 lines / 50 KB
- **No TinyFish provider** — v2 ships it (`agent.tinyfish.ai/mcp`) but its docs omit it, it exists on only one of the two release lines, and it depends on JSON hidden inside MCP text content; revisit if it stabilizes
- **Credential-aware random candidates** — v2 registers all providers regardless of credentials; this extension excludes keyless-unusable providers (Tavily without `TAVILY_API_KEY`) from random routing, because its 503 endpoint cannot trigger the 429-only failover and there is no consent flow to gate it earlier
- **Tool description wording** — v2 says "Search the web using the user's selected search integration" (accurate for its consent/KV selection and integrations UI); this extension has no user-facing selection, so the first sentence is just "Search the web"

## Differences from the previous version of this extension

- Mirrors OpenCode **v2** instead of `e4bd9757a` (dev line)
- Providers: +Firecrawl, +Tavily (Exa and Parallel were already there); FNV-1a hash A/B routing replaced by v2's random/affinity/cooldown/failover model
- `numResults` tool parameter removed (fixed at 8 internally, as in v2)
- Results are parsed to structured objects and formatted as markdown instead of passing provider text through verbatim; Parallel now reads `structuredContent` (and no longer sends `session_id`/`model_name`)
- MCP tool errors (`isError`) now throw instead of being returned inline with a prefix
- Truncation notice uses pi's bracket format
