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

function assertHttpUrl(url: URL): void {
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("URL must use http:// or https://");
  }
  if (url.username || url.password) throw new Error("URL must not include credentials");
}

function sanitizeUrl(value: string): string {
  const url = value.split("#")[0];
  assertHttpUrl(new URL(url));
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

interface FetchResult {
  contentType: string;
  arrayBuffer: ArrayBuffer;
}

// Manual redirects let us validate each destination before contacting it.
async function fetchFollowingRedirects(
  url: string,
  headers: Record<string, string>,
  signal: AbortSignal,
): Promise<Response> {
  let current = url;
  for (let redirects = 0; ; redirects++) {
    const response = await fetch(current, { headers, signal, redirect: "manual" });
    const location = response.headers.get("location");
    if (!REDIRECT_STATUSES.has(response.status) || !location) return response;

    // Drain the redirect body to release the TCP connection back to the pool.
    await response.arrayBuffer().catch(() => {});
    if (redirects >= MAX_REDIRECTS) {
      throw new Error(`Too many redirects (more than ${MAX_REDIRECTS})`);
    }

    const target = new URL(location, current);
    target.hash = "";
    assertHttpUrl(target);
    current = target.href;
  }
}

async function fetchUrl(
  url: string,
  acceptHeader: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<FetchResult> {
  const fetchStartTime = Date.now();

  // Keep user cancellation linked across both attempts and body reads.
  const externalController = new AbortController();
  if (signal?.aborted) externalController.abort();
  const onExternalAbort = () => externalController.abort();
  signal?.addEventListener("abort", onExternalAbort, { once: true });

  try {
    const firstController = new AbortController();
    const firstTimeoutId = setTimeout(() => firstController.abort(), timeoutMs);
    const firstSignal = AbortSignal.any([externalController.signal, firstController.signal]);

    let response: Response;
    try {
      const headers = buildHeaders(acceptHeader, openCodeUserAgent);
      response = await fetchFollowingRedirects(url, headers, firstSignal);
    } finally {
      clearTimeout(firstTimeoutId);
    }

    if (response.status === 403 && response.headers.get("cf-mitigated") === "challenge") {
      // Release the challenged response before retrying.
      await response.arrayBuffer().catch(() => {});

      // The retry shares the first attempt's deadline; the final body read has no attempt timer.
      const retryDeadline = timeoutMs - (Date.now() - fetchStartTime);
      if (retryDeadline <= 0) {
        throw new Error(`Request timed out after ${timeoutMs / 1000}s`);
      }

      const retryController = new AbortController();
      const retryTimeoutId = setTimeout(() => retryController.abort(), retryDeadline);
      const retrySignal = AbortSignal.any([externalController.signal, retryController.signal]);

      try {
        // Restart at the original URL so the retry also follows and validates redirects.
        const retryHeaders = buildHeaders(acceptHeader, CLOUDFLARE_RETRY_UA);
        response = await fetchFollowingRedirects(url, retryHeaders, retrySignal);
      } finally {
        clearTimeout(retryTimeoutId);
      }
    }

    // Drain failed responses to release the connection.
    if (!response.ok) {
      await response.arrayBuffer().catch(() => {});
      throw new Error(`HTTP ${response.status} ${response.statusText}`);
    }

    const contentType = response.headers.get("content-type") || "";
    const mime = mimeFrom(contentType);
    const isImage = isImageAttachment(mime);
    if (isImage || !isTextualMime(mime)) {
      await response.body?.cancel().catch(() => {});
      const kind = isImage ? "image" : "file";
      throw new Error(`Unsupported fetched ${kind} content type: ${mime}`);
    }

    // Check both the declared size and the actual body; the header is optional.
    const contentLength = response.headers.get("content-length");
    if (contentLength && parseInt(contentLength, 10) > MAX_RESPONSE_SIZE) {
      throw new Error(`Response too large (exceeds ${MAX_RESPONSE_SIZE} byte limit)`);
    }

    const arrayBuffer = await response.arrayBuffer();
    if (arrayBuffer.byteLength > MAX_RESPONSE_SIZE) {
      throw new Error(`Response too large (exceeds ${MAX_RESPONSE_SIZE} byte limit)`);
    }

    return { contentType, arrayBuffer };
  } catch (err: any) {
    if (err.name === "AbortError") {
      if (signal?.aborted) {
        throw new RequestCancelledError("Request was cancelled");
      }
      throw new Error(`Request timed out after ${timeoutMs / 1000}s`);
    }
    throw err;
  } finally {
    signal?.removeEventListener("abort", onExternalAbort);
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
        const { contentType, arrayBuffer } = await fetchUrl(
          url,
          buildAcceptHeader(format),
          timeout,
          signal,
        );
        details.contentType = contentType;

        const content = new TextDecoder().decode(arrayBuffer);
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
        if (err instanceof RequestCancelledError) throw err;
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
