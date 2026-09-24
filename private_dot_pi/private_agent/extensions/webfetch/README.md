# Pi WebFetch Extension

Adds a `webfetch` tool to [pi](https://pi.dev) that fetches content from URLs and converts it to markdown, text, or HTML format. Mirrors OpenCode **v2**'s webfetch implementation ([anomalyco/opencode](https://github.com/anomalyco/opencode/tree/9c8a63e852722a9bced4a0de1179de58a85dfa20), `v2` branch, 2026-09-23).

## How It Works

1. Validates the URL (`http://` / `https://` only, fail-fast like v2)
2. Fetches with format-aware `Accept` headers and the **OpenCode-User** UA (`Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; OpenCode-User/1.0; +https://opencode.ai`)
3. If blocked by Cloudflare (403 + `cf-mitigated: challenge`), drains the 403 response and retries with the bare `opencode` UA (within the same total timeout budget)
4. Classifies the response: images are returned as base64 image attachments (non-SVG; SVG is textual); non-textual mimes fail (`Unsupported fetched file content type`); everything else decodes
5. Converts by content type and requested format:
   - **HTML + markdown** → v2's own htmlparser2 renderer (`html-markdown.ts`, ported verbatim)
   - **HTML + text** → htmlparser2 SAX extraction with a skip-depth counter (`script, style, noscript, iframe, object, embed`)
   - **HTML + html** → raw HTML
   - **Non-HTML textual** → content as-is
6. Truncates output (2000 lines / 50KB) with pi's bracket-format notice, saving the full output to a temp file
7. Every failure surfaces as `Unable to fetch <url>` with the cause attached

## Setup

```bash
cd private_dot_pi/private_agent/extensions/webfetch && npm install
```

(one dependency: `htmlparser2` — same as upstream)

## Tool Parameters

| Parameter | Type                                 | Default      | Description                                                 |
| --------- | ------------------------------------ | ------------ | ----------------------------------------------------------- |
| `url`     | string (required)                    | —            | The URL to fetch content from                               |
| `format`  | `"text"` \| `"markdown"` \| `"html"` | `"markdown"` | The format to return the content in                         |
| `timeout` | number (> 0, ≤ 120)                  | 30           | Optional timeout in seconds (fail-fast via schema, like v2) |

## Limits

| Limit             | Value                                   |
| ----------------- | --------------------------------------- |
| Max response size | 5MB (shared with the renderer's budget) |
| Default timeout   | 30 seconds                              |
| Max timeout       | 120 seconds                             |
| URL scheme        | `http://` or `https://` only            |
| Output truncation | 2000 lines or 50KB                      |

## Output Truncation

Output is truncated to 2000 lines or 50 KB (pi's built-in limits). When truncated, the full output is saved to a temp file and the LLM is informed with pi's bash-tool bracket format: `[Showing lines 1-N of M. Full output: <path>]`.

**Known caveat, inherited from v2:** the markdown renderer caps conversion output at ~5MB (`CONTENT_BYTES` — v2's anti-DoS budget, with a 64KB structural margin). When a page's markdown conversion exceeds that budget (escaping-dense multi-MB HTML can expand past its source size), the tail past the budget is silently dropped and the "full output" temp file holds the capped conversion, not the complete one. Upstream v2 has the identical chain, and its docs make the same overclaim ("the full text is retained in managed storage"). Deliberately mirrored rather than fixed locally — a disclosure fix would be a deviation from upstream's silence; revisit if upstream adds disclosure semantics.

## Architecture

```
webfetch/
├── index.ts          # Tool registration, fetch, format dispatch, error narrowing, truncation,
│                     #   extractTextFromHTML (like upstream; exported for tests)
├── html-markdown.ts  # v2's htmlparser2 markdown renderer, ported verbatim (excluded from oxfmt
│                     #   so drift diffs stay byte-comparable)
├── render.ts         # Custom TUI rendering
├── package.json      # htmlparser2 only
└── README.md
```

## Differences from OpenCode v2's WebFetch

- **Images kept** — v2 removed image delivery (`Unsupported fetched image content type`); this extension returns non-SVG images as pi-native `{ type: "image" }` content (base64 + mimeType), SVG as text
- **No permission gate** — v2 requires `webfetch` permission; this extension does not
- **No Effect framework** — plain async/await + TypeBox instead of Effect Schema
- **Per-attempt timeout controllers** — v2 wraps retry in `Effect.timeoutOrElse`; here each attempt gets its own `AbortController` with the remaining budget
- **Response body draining** — non-2xx and 403 response bodies are drained to release TCP connections; v2 relies on Effect's resource management
- **User cancellation bypasses the error wrap** — `Unable to fetch <url>` mirrors v2's error narrowing, but genuine user aborts keep their plain "Request was cancelled" message (pi abort semantics)
- **Description wording** — v2's "retained in managed storage" sentence adapted to this extension's temp-file truncation
- **Renderer** — `html-markdown.ts` ported verbatim from v2 (it replaced turndown in 90fd61225) and excluded from oxfmt via `ignorePatterns`, keeping drift diffs byte-comparable; no turndown/cheerio dependencies remain

## Drift Notes

- dev line since `5fb85a6a` (the previous pin): only `2d2f587bf` (nullable format schema fix — TypeBox optional-with-default never had that bug)
- v2 commits behind this mirror: `90fd61225` (renderer swap), `0762d63b6` (OpenCode-User UA), `367cf5961` (error narrowing), plus schema/description cleanups
- Direction signal (unmerged): `web-fetch` branch moves fetch into a policy-bound codemode Web extension — the fetch layer may be replaced wholesale next sync
