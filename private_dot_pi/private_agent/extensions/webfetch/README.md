# Pi WebFetch Extension

Adds a `webfetch` tool to [pi](https://pi.dev) that fetches content from URLs and converts it to markdown, text, or HTML format. Mirrors [OpenCode](https://github.com/anomalyco/opencode)'s webfetch implementation.

## How It Works

1. Fetches the URL with format-aware `Accept` headers and a browser-like `User-Agent`
2. If blocked by Cloudflare (403 + `cf-mitigated: challenge`), drains the 403 response and retries with an honest UA (within the same total timeout budget)
3. Handles the response based on content type and requested format:
   - **HTML + markdown** → converts HTML to Markdown (mirrors TurndownService)
   - **HTML + text** → extracts plain text (mirrors Cloudflare HTMLRewriter)
   - **HTML + html** → returns raw HTML
   - **Non-HTML** → returns content as-is
   - **Images** (PNG, JPEG, etc.) → returns as base64 image attachments
   - **SVG** → returns as text (not treated as image)
4. Truncates output if needed (2000 lines / 50KB), saving full output to a temp file

## Setup

No setup required — the tool works out of the box.

## Tool Parameters

| Parameter | Type                                 | Default      | Description                           |
| --------- | ------------------------------------ | ------------ | ------------------------------------- |
| `url`     | string (required)                    | —            | The URL to fetch content from         |
| `format`  | `"text"` \| `"markdown"` \| `"html"` | `"markdown"` | The format to return the content in   |
| `timeout` | number                               | 30           | Optional timeout in seconds (max 120) |

## Limits

| Limit             | Value                        |
| ----------------- | ---------------------------- |
| Max response size | 5MB                          |
| Default timeout   | 30 seconds                   |
| Max timeout       | 120 seconds                  |
| URL scheme        | `http://` or `https://` only |
| Output truncation | 2000 lines or 50KB           |

## Output Truncation

Output is truncated to 2000 lines or 50 KB (whichever is hit first). When truncated, the full output is saved to a temp file and the LLM is informed of the path.

## Architecture

```
webfetch/
├── index.ts          # Main entry: tool registration, HTTP fetch, format dispatch, truncation
├── html-convert.ts   # HTML→Markdown and HTML→text conversion
├── render.ts         # Custom TUI rendering
└── README.md
```

## Differences from OpenCode's WebFetch

- **No permission gate** — OpenCode requires `webfetch` permission; this extension does not
- **No Effect framework** — Uses plain async/await instead of Effect.ts
- **Image delivery** — Uses pi's `{ type: "image", data, mimeType }` content format instead of OpenCode's `attachments` array
- **cheerio instead of HTMLRewriter** — Uses cheerio for HTML-to-text extraction (mirrors HTMLRewriter's skip behavior), since HTMLRewriter is Cloudflare Workers-specific
- **Per-attempt timeout controllers** — OpenCode wraps retry in `Effect.timeoutOrElse`; here each attempt gets its own `AbortController` with the remaining budget
- **Response body draining** — Drains non-2xx and 403 response bodies to release TCP connections; OpenCode relies on Effect's resource management

## Dependencies

- [`turndown`](https://github.com/mixmark-io/turndown) — HTML-to-Markdown conversion (same library as OpenCode)
- [`cheerio`](https://github.com/cheeriojs/cheerio) — HTML parsing for text extraction
