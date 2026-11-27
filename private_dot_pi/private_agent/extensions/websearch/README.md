# Pi WebSearch

Search the web from Pi with Exa, Firecrawl, Parallel, Tavily, or TinyFish. Mirrors [OpenCode websearch at `c85b83eb08`](https://github.com/anomalyco/opencode/tree/c85b83eb08c3d2666b842848215325acb282d92b) (`dev`, 2026-11-25).

## Usage

The tool accepts one required parameter, `query`. Set `PI_WEBSEARCH_PROVIDER` to a provider ID below to force it, or leave it unset (or set it to `random`) for session-sticky random selection. All five providers are eligible for random routing even without a key; keyless requests depend on each provider's free tier.

| Provider ID | API key environment variable | Transport |
| --- | --- | --- |
| `exa` | `EXA_API_KEY` | MCP over HTTPS |
| `firecrawl` | `FIRECRAWL_API_KEY` | MCP over HTTPS |
| `parallel` | `PARALLEL_API_KEY` | MCP over HTTPS |
| `tavily` | `TAVILY_API_KEY` | REST |
| `tinyfish` | `TINYFISH_API_KEY` | MCP over HTTPS |

**Random** routing sticks to one provider per session and restores it on resume. Only HTTP 429 triggers failover: the provider enters cooldown for its `Retry-After` duration (or 60 seconds if missing or invalid), and the query immediately tries another available provider. If all providers are cooling down, the call fails with a rate-limit error. A non-429 failure does not move the sticky selection; force a different provider if a keyless tier keeps failing.

**Forced** routing makes one attempt with the chosen provider, bypassing cooldown and failover.

TinyFish makes one `tools/call` without a key. With a key, each search negotiates a session (`initialize` → `notifications/initialized` → `tools/call` with `Mcp-Session-Id`).

**Known limitation (shared with pinned upstream):** the MCP client caps each response at 256 KiB, but Tavily's REST path reads the entire response body without a byte cap. Large responses can consume memory while being read and parsed, and their hits are copied into the codemode sandbox before scripts can filter them. Codemode's final output budget does not protect these steps. If a bounded response is needed, force an MCP provider. A future Tavily cap should reject oversized bodies during streaming, not truncate the hits.

## Output

**Direct calls** display Markdown with linked titles, dates when present, and snippets. If output exceeds 2000 lines or 50 KiB, the preview links to a file containing the full Markdown. If saving fails, the preview remains available, and the notice and `details.fullOutputError` report why.

**Codemode** returns an array of hits in provider order: `{ url: string; title?: string; published?: number; content?: string }[]`. `published` is Unix time in milliseconds. No hits returns `[]`. The Markdown preview budget does not trim these hits; codemode's own output budget applies to what the script sends back to the model.

Malformed hits fail the call with `Unable to search the web for <query>`; they are not dropped from an otherwise successful result.

```js
const hits = await tools.websearch({ query: "Pi release notes" });
text(hits.map(({ url, title }) => ({ url, title })));
```

## Differences from Upstream

- **Providers and exposure:** Claude Agent is omitted because it depends on OpenCode's account and runtime. Pi controls direct and codemode availability, without OpenCode's catalog pinning.
- **Configuration:** credentials and provider choice come from environment variables rather than integration connections, consent, or managed policy. The description does not claim a provider picker. Random affinity is written to a `websearch.selection` session entry for resume, not to a global provider preference.
- **MCP transport:** the client uses TypeBox and AbortController instead of Effect. It sends Pi's `MCP-Protocol-Version` header on each request and uses the negotiated version after TinyFish initialization. Parallel, Tavily, Firecrawl, and TinyFish identify as Pi; TinyFish also does so in `clientInfo`.
- **TinyFish parsing:** a missing `results` array fails rather than becoming an empty result.
- **Preview storage:** the tool uses Pi's bracket notices and a local Markdown temp file; a failed save does not fail the search. User cancellation bypasses generic error wrapping.

## Verification

From the chezmoi root, run `cd private_dot_pi/private_agent && npm exec -- vitest --run tests/websearch.test.ts`.

## Drift Notes

- `c85b83eb08`: ported the flat hit array (`8a30e585a6`) and small-field-first ordering (`5756d59a68`); provider metadata stays separate. Claude Agent (`8bae58e7b9`) is deliberately omitted. OpenCode's Code Mode exposure, pinning, and plugin readiness changes remain upstream-only. Unmerged `websearch-*` branches are direction signals.
- `ba06ff9e0b`: ported TinyFish's keyed session handshake (`86755e1cea`). Golden checks cover observed server behavior, including HTTP 204 for the initialization notification.
