# Pi WebSearch Extension

Adds a `websearch` tool to [pi](https://pi.dev) that searches the internet using [Exa](https://exa.ai) or [Parallel](https://parallel.ai) via their remote MCP-over-HTTP endpoints.

## Setup

No setup required — both providers work on their free tiers without API keys.

To unlock higher rate limits, set an API key:

```bash
# Exa (https://exa.ai)
export EXA_API_KEY=exa-...

# Parallel (https://parallel.ai)
export PARALLEL_API_KEY=...
```

Then start pi — the `websearch` tool is automatically available.

## Provider Selection

Both Exa and Parallel have **free tiers** that work without API keys. Keys unlock higher rate limits.

Provider selection mirrors OpenCode exactly:

| Scenario                         | Provider                                              |
| -------------------------------- | ----------------------------------------------------- |
| `PI_WEBSEARCH_PROVIDER=exa`      | Exa (forced)                                          |
| `PI_WEBSEARCH_PROVIDER=parallel` | Parallel (forced)                                     |
| No override (default)            | Deterministic A/B routing per session via FNV-1a hash |

API keys are for authentication only — they do **not** affect which provider is selected.

## Tool Parameters

| Parameter    | Type              | Default | Description       |
| ------------ | ----------------- | ------- | ----------------- |
| `query`      | string (required) | —       | Search query      |
| `numResults` | integer (≥1)      | 8       | Number of results |

## Output Truncation

Output is truncated to 2000 lines or 50 KB (whichever is hit first). When truncated, the full output is saved to a temp file and the LLM is informed of the path.

## Architecture

```
websearch/
├── index.ts              # Main entry: tool registration, provider routing, truncation
├── mcp-client.ts         # Generic MCP-over-HTTP client (JSON-RPC 2.0 + SSE parsing)
├── providers/
│   ├── types.ts           # Shared types
│   ├── exa.ts             # Exa provider (web_search_exa)
│   └── parallel.ts        # Parallel provider (web_search)
├── render.ts             # Custom TUI rendering
└── README.md
```

No local MCP server processes are started. All calls go to remote MCP endpoints via HTTPS.
