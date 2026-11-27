// Mirrors OpenCode's webfetch; see README.md for the upstream pin and differences.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  truncateHead,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { type Static, Type } from "typebox";

import { Parser } from "htmlparser2";
import { convertHTMLToMarkdown, MAX_MARKDOWN_BYTES } from "./html-markdown";
import {
  formatWebfetchCall,
  rebuildWebfetchResultRenderComponent,
  WebfetchResultRenderComponent,
  type WebfetchDetails,
  type WebfetchRenderState,
} from "./render";

const MAX_RESPONSE_SIZE = MAX_MARKDOWN_BYTES; // 5MB, shared with renderer budget
const DEFAULT_TIMEOUT = 30 * 1000; // 30 seconds
const MAX_TIMEOUT_SECONDS = 120;

export const MAX_REDIRECTS = 10;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);

// Only messages built by this tool bypass the generic error wrapper.
class WebfetchRequestError extends Error {
  override name = "WebfetchRequestError";
}

function assertHttpUrl(url: URL): void {
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new WebfetchRequestError("URL must use http:// or https://");
  }
  if (url.username || url.password)
    throw new WebfetchRequestError("URL must not include credentials");
}

function sanitizeUrl(value: string): string {
  const url = value.split("#")[0];
  const parsed = URL.parse(url);
  if (!parsed) throw new WebfetchRequestError("Invalid URL");
  assertHttpUrl(parsed);
  return url;
}

const mimeFrom = (contentType: string) => contentType.split(";", 1)[0]?.trim().toLowerCase() ?? "";

function isImageAttachment(mime: string): boolean {
  return mime.startsWith("image/") && mime !== "image/svg+xml" && mime !== "image/vnd.fastbidsheet";
}

function isTextualMime(mime: string): boolean {
  return (
    !mime ||
    mime.startsWith("text/") ||
    mime === "application/json" ||
    mime.endsWith("+json") ||
    mime === "application/xml" ||
    mime.endsWith("+xml") ||
    mime === "application/javascript" ||
    mime === "application/x-javascript"
  );
}

function buildAcceptHeader(format: "text" | "markdown" | "html"): string {
  switch (format) {
    case "markdown":
      return "text/markdown;q=1.0, text/x-markdown;q=0.9, text/plain;q=0.8, text/html;q=0.7, */*;q=0.1";
    case "text":
      return "text/plain;q=1.0, text/markdown;q=0.9, text/html;q=0.8, */*;q=0.1";
    case "html":
      return "text/html;q=1.0, application/xhtml+xml;q=0.9, text/plain;q=0.8, text/markdown;q=0.7, */*;q=0.1";
  }
}

const openCodeUserAgent =
  "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; OpenCode-User/1.0; +https://opencode.ai";
const CLOUDFLARE_RETRY_UA = "opencode";

function buildHeaders(acceptHeader: string, userAgent: string): Record<string, string> {
  return {
    "User-Agent": userAgent,
    Accept: acceptHeader,
    "Accept-Language": "en-US,en;q=0.9",
  };
}

/** Keep foreign errors from impersonating a user cancellation by message text. */
export class RequestCancelledError extends Error {
  override name = "RequestCancelledError";
}

function discardBody(response: Response): void {
  void response.body?.cancel().catch(() => {});
}

// Manual redirects let us validate each destination before contacting it.
async function fetchFollowingRedirects(
  url: string,
  headers: Record<string, string>,
  signal: AbortSignal,
): Promise<{ response: Response; url: string }> {
  let current = url;
  for (let redirects = 0; ; redirects++) {
    signal.throwIfAborted();
    const response = await fetch(current, { headers, signal, redirect: "manual" });
    const location = response.headers.get("location");
    if (!REDIRECT_STATUSES.has(response.status) || !location) return { response, url: current };

    discardBody(response);
    if (redirects >= MAX_REDIRECTS) {
      throw new WebfetchRequestError(`Too many redirects (more than ${MAX_REDIRECTS})`);
    }

    const target = URL.parse(location, current);
    if (!target) throw new WebfetchRequestError("Invalid URL");
    target.hash = "";
    assertHttpUrl(target);
    current = target.href;
  }
}

async function readResponseBody(
  response: Response,
  signal: AbortSignal,
): Promise<Buffer<ArrayBuffer>> {
  const declared = Number.parseInt(response.headers.get("content-length") ?? "", 10);
  const declaredSize = Number.isSafeInteger(declared) && declared >= 0 ? declared : 0;
  const tooLarge = `Response too large (exceeds ${MAX_RESPONSE_SIZE} byte limit)`;
  if (declaredSize > MAX_RESPONSE_SIZE) {
    discardBody(response);
    throw new WebfetchRequestError(tooLarge);
  }
  if (!response.body) return Buffer.alloc(0);

  const reader = response.body.getReader();
  // Cancel a pending read even if the response stream is not tied to fetch's signal.
  const onAbort = () => {
    void reader.cancel().catch(() => {});
  };
  signal.addEventListener("abort", onAbort, { once: true });
  let body = Buffer.allocUnsafe(declaredSize || 64 * 1024);
  let size = 0;
  try {
    signal.throwIfAborted();
    for (;;) {
      const { done, value } = await reader.read();
      signal.throwIfAborted();
      if (done) return body.subarray(0, size);
      const nextSize = size + value.byteLength;
      if (nextSize > MAX_RESPONSE_SIZE) {
        void reader.cancel().catch(() => {});
        throw new WebfetchRequestError(tooLarge);
      }
      if (nextSize > body.byteLength) {
        const grown = Buffer.allocUnsafe(
          Math.min(MAX_RESPONSE_SIZE, Math.max(nextSize, body.byteLength * 2)),
        );
        body.copy(grown, 0, 0, size);
        body = grown;
      }
      body.set(value, size);
      size = nextSize;
    }
  } finally {
    signal.removeEventListener("abort", onAbort);
    reader.releaseLock();
  }
}

async function fetchUrl(
  url: string,
  acceptHeader: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<{ contentType: string; body: Buffer<ArrayBuffer> }> {
  const timeout = new AbortController();
  const timer = setTimeout(() => timeout.abort(), timeoutMs);
  const fetchSignal = signal ? AbortSignal.any([signal, timeout.signal]) : timeout.signal;

  try {
    let result = await fetchFollowingRedirects(
      url,
      buildHeaders(acceptHeader, openCodeUserAgent),
      fetchSignal,
    );

    if (
      result.response.status === 403 &&
      result.response.headers.get("cf-mitigated") === "challenge"
    ) {
      discardBody(result.response);
      result = await fetchFollowingRedirects(
        url,
        buildHeaders(acceptHeader, CLOUDFLARE_RETRY_UA),
        fetchSignal,
      );
    }

    const { response, url: requestUrl } = result;
    if (fetchSignal.aborted) {
      discardBody(response);
      fetchSignal.throwIfAborted();
    }
    if (!response.ok) {
      discardBody(response);
      throw new WebfetchRequestError(
        `StatusCode: non 2xx status code (${response.status} GET ${requestUrl})`,
      );
    }

    const contentType = response.headers.get("content-type") || "";
    const mime = mimeFrom(contentType);
    const isImage = isImageAttachment(mime);
    if (isImage || !isTextualMime(mime)) {
      discardBody(response);
      const kind = isImage ? "image" : "file";
      // Reflect only bounded MIME names, not arbitrary header text.
      const label = /^[a-z0-9][a-z0-9!#$&^_.+-]{0,126}\/[a-z0-9][a-z0-9!#$&^_.+-]{0,126}$/.test(
        mime,
      )
        ? `: ${mime}`
        : "";
      throw new WebfetchRequestError(`Unsupported fetched ${kind} content type${label}`);
    }

    return { contentType, body: await readResponseBody(response, fetchSignal) };
  } catch (err) {
    if (signal?.aborted) throw new RequestCancelledError("Request was cancelled");
    if (timeout.signal.aborted) throw new WebfetchRequestError("Request timed out", { cause: err });
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

function convert(
  content: string,
  contentType: string,
  format: "text" | "markdown" | "html",
): string {
  if (!contentType.includes("text/html")) return content;
  if (format === "markdown") return convertHTMLToMarkdown(content);
  if (format === "text") return extractTextFromHTML(content);
  return content;
}

type SavedFullOutput = { path: string } | { error: string };

async function saveFullOutput(prefix: string, text: string): Promise<SavedFullOutput> {
  let dir: string | undefined;
  try {
    dir = await mkdtemp(join(tmpdir(), prefix));
    const path = join(dir, "output.txt");
    await writeFile(path, text, "utf8");
    return { path };
  } catch (err) {
    if (dir) await rm(dir, { recursive: true, force: true }).catch(() => {});
    return { error: err instanceof Error ? err.message : String(err) };
  }
}

const WebFetchParamsSchema = Type.Object({
  url: Type.String({
    description: "The HTTP or HTTPS URL to fetch content from",
  }),
  format: Type.Optional(
    Type.Enum(["text", "markdown", "html"] as const, {
      description: "The format to return the content in. Defaults to markdown.",
    }),
  ),
  timeout: Type.Optional(
    Type.Number({
      exclusiveMinimum: 0,
      maximum: MAX_TIMEOUT_SECONDS,
      description: `Optional timeout in seconds (maximum: ${MAX_TIMEOUT_SECONDS})`,
    }),
  ),
});

const WebFetchOutputSchema = Type.Object({
  contentType: Type.String(),
  output: Type.String(),
});

// Pi uses a local temp file rather than OpenCode's managed storage.
const DESCRIPTION = `Fetch content from an HTTP or HTTPS URL and return it as text, markdown, or HTML. Markdown is the default.

Use a more targeted tool when one is available. This tool is read-only. Large text results may be truncated while the complete output is saved to a temporary file.`;

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "webfetch",
    label: "Web Fetch",
    description: DESCRIPTION,
    parameters: WebFetchParamsSchema,
    outputSchema: WebFetchOutputSchema,

    async execute(
      _toolCallId,
      params,
      signal,
      onUpdate,
      _ctx,
    ): Promise<{
      content: Array<{ type: "text"; text: string }>;
      details: WebfetchDetails;
      structuredContent: Static<typeof WebFetchOutputSchema>;
    }> {
      const format: "markdown" | "text" | "html" =
        (params.format as "markdown" | "text" | "html") ?? "markdown";
      const timeout = (params.timeout ?? DEFAULT_TIMEOUT / 1000) * 1000;

      const details: WebfetchDetails = {
        url: params.url,
        format,
      };

      onUpdate?.({
        content: [{ type: "text", text: `Fetching ${params.url}...` }],
        details,
      });

      try {
        const url = sanitizeUrl(params.url);
        const { contentType, body } = await fetchUrl(
          url,
          buildAcceptHeader(format),
          timeout,
          signal,
        );
        details.contentType = contentType;

        const content = new TextDecoder().decode(body);
        const output = convert(content, contentType, format);

        // Only the model-facing preview is trimmed; scripts get the conversion as produced.
        const truncation = truncateHead(output, {
          maxLines: DEFAULT_MAX_LINES,
          maxBytes: DEFAULT_MAX_BYTES,
        });

        let resultText = truncation.content;

        if (truncation.truncated) {
          details.truncation = truncation;
          const saved = await saveFullOutput("pi-webfetch-", output);
          if ("path" in saved) {
            details.fullOutputPath = saved.path;
          } else {
            details.fullOutputError = saved.error;
          }

          const fullOutput =
            "path" in saved
              ? `Full output: ${saved.path}`
              : `Could not save the full output: ${saved.error}`;
          const startLine = 1;
          const endLine = truncation.outputLines;
          if (truncation.truncatedBy === "lines") {
            resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines}. ${fullOutput}]`;
          } else {
            resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines} (${formatSize(DEFAULT_MAX_BYTES)} limit). ${fullOutput}]`;
          }
        }

        return {
          content: [{ type: "text", text: resultText }],
          details,
          structuredContent: { contentType, output },
        };
      } catch (err) {
        if (err instanceof WebfetchRequestError || err instanceof RequestCancelledError) throw err;
        throw new Error(`Unable to fetch ${params.url}`, {
          cause: err instanceof Error ? err : new Error(String(err)),
        });
      }
    },

    renderCall(args, theme, context) {
      const state = context.state as WebfetchRenderState;
      if (context.executionStarted && state.startedAt === undefined) {
        state.startedAt = Date.now();
        state.endedAt = undefined;
      }

      const text = (context.lastComponent as Text) ?? new Text("", 0, 0);
      text.setText(
        formatWebfetchCall(
          {
            url: args?.url,
            format: args?.format,
          },
          theme,
        ),
      );
      return text;
    },

    renderResult(result, options, theme, context) {
      const state = context.state as WebfetchRenderState;

      if (state.startedAt !== undefined && options.isPartial && !state.interval) {
        state.interval = setInterval(() => context.invalidate(), 1000);
      }

      if (!options.isPartial) {
        state.endedAt ??= Date.now();
        if (state.interval) {
          clearInterval(state.interval);
          state.interval = undefined;
        }
      }

      const component =
        (context.lastComponent as WebfetchResultRenderComponent | undefined) ??
        new WebfetchResultRenderComponent();
      rebuildWebfetchResultRenderComponent(
        component,
        result as any,
        options,
        theme,
        state,
        context.isError,
        context,
      );
      component.invalidate();
      return component;
    },
  });
}

// Ported from OpenCode's webfetch; exported for the golden tests.
export function extractTextFromHTML(html: string): string {
  let text = "";
  let skipDepth = 0;
  const parser = new Parser({
    onopentag(name) {
      if (
        skipDepth > 0 ||
        ["script", "style", "noscript", "iframe", "object", "embed"].includes(name)
      )
        skipDepth++;
    },
    ontext(input) {
      if (skipDepth === 0) text += input;
    },
    onclosetag() {
      if (skipDepth > 0) skipDepth--;
    },
  });
  parser.write(html);
  parser.end();
  return text.trim();
}
