# Pi WebFetch

Fetch HTTP(S) content as Markdown, plain text, or HTML in Pi. Mirrors [OpenCode webfetch at `c85b83eb08`](https://github.com/anomalyco/opencode/tree/c85b83eb08c3d2666b842848215325acb282d92b) (`dev`, 2026-11-25).

## Usage

Install dependencies with `npm install` in this directory.

| Parameter | Meaning |
| --- | --- |
| `url` | Required HTTP(S) URL. Credentials are rejected; fragments are stripped. |
| `format` | `"markdown"` (default), `"text"`, or `"html"`. Applies to HTML responses; other textual responses pass through. |
| `timeout` | Request and body-reading deadline in seconds, including redirects and retry. Defaults to 30; must be greater than 0 and at most 120. |

The tool validates each redirect target and follows up to 10 hops. It rejects binary images and other non-textual responses; SVG passes through as text. Direct calls and codemode scripts see actionable errors for invalid URLs, HTTP status codes, timeouts, unsupported media, oversized responses, and redirect limits. If the request or response stream fails, the error is `Transport error (GET <url>)` for the failed hop. Unexpected errors use `Unable to fetch <url>` without exposing the original exception to the model.

## Output

**Direct calls** show converted text. If it exceeds 2000 lines or 50 KiB, the preview includes a path to the full conversion. If saving fails, the preview remains available, and the notice and `details.fullOutputError` report why.

**Codemode** returns `{ contentType, output }`. `contentType` is the original response header (or `""`), not the format of the conversion. `output` is the converted text before preview truncation, with no continuation notice.

```js
const { output } = await tools.webfetch({ url: "https://example.com", format: "text" });
text(output.slice(0, 1000));
```

The HTTP response body is capped at 5 MiB while streaming. Separately, Markdown conversion has its own size budget and can silently omit the tail. Both the temp file and codemode result contain the conversion as produced, not the raw HTTP body or any omitted Markdown.

## Differences from Upstream

- **Tool exposure:** OpenCode excludes `webfetch` from Code Mode (`codemode: false`) and hides the direct tool in full Code Mode. Its scripts use a permission-checked global `fetch()` for HTTP responses, without automatic Markdown conversion. Pi's sandbox has no global `fetch()`, so this mirror exposes `tools.webfetch()` and reuses the upstream tool's structured result shape.
- **Permission:** the mirror has no OpenCode permission prompt, saved site rule, or per-hop authorization check. URL validation still applies at every hop.
- **Preview storage:** Pi uses its own bracket notices and a temporary file rather than OpenCode's managed storage. A failed save is nonfatal.
- **Errors:** Pi reproduces OpenCode's session-facing messages for known failures. HTTP errors include the failed request URL, but not the remote status text or body. Unlike OpenCode's session unwrapping, Pi keeps the generic fallback for unexpected exceptions and only echoes well-formed MIME names. User cancellation keeps its own message.
- **Runtime:** async/await and TypeBox instead of Effect.

## Verification

From the chezmoi root, run `npm --prefix private_dot_pi/private_agent/extensions/webfetch test`. Keep [`html-markdown.ts`](html-markdown.ts) byte-identical to the pinned upstream renderer; it is exempt from formatting.

## Drift Notes

- `c85b83eb08`: ported `{ contentType, output }` (`d9d0a46d46`), removed the local binary-image attachment branch, and verified the renderer is unchanged. Site-scoped permission persistence (`c6df401531`) remains upstream-only. Unmerged `codemode-webfetch` and `web-fetch` are direction signals.
