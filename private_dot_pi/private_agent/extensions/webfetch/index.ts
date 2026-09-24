/**
 * Pi WebFetch Extension
 *
 * Adds a `webfetch` tool that fetches content from URLs and converts to
 * markdown, text, or HTML format.
 *
 * Mirrors OpenCode v2's webfetch implementation
 * (packages/core/src/tool/plugin/webfetch.ts, pinned commit in README):
 * - URL validation (http/https only)
 * - Format parameter: markdown (default), text, or html
 * - Accept header strategy based on requested format
 * - OpenCode-User UA by default; plain "opencode" UA on Cloudflare
 *   403 challenge retry (v2 0762d63b6)
 * - Response body draining on error to release TCP connections
 * - Response size limit (5MB, shared with the markdown renderer budget)
 * - Textual mime whitelist; non-textual content types fail
 * - HTML→Markdown via v2's own htmlparser2 renderer (html-markdown.ts,
 *   ported verbatim and excluded from oxfmt so drift diffs stay
 *   byte-comparable; turndown is gone from upstream since 90fd61225)
 * - Output truncation with temp file fallback
 * - Image handling (base64 for non-SVG, text for SVG) — pi-native keep;
 *   v2 removed images, this extension keeps them (ledger deviation)
 * - Error narrowing: every failure surfaces as "Unable to fetch <url>"
 *   with the cause attached (v2 367cf5961)
 * - No permission gate (unlike OpenCode which requires webfetch permission)
 */

import { StringEnum } from "@earendil-works/pi-ai";
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
import { Type } from "typebox";

import { Parser } from "htmlparser2";
import { convertHTMLToMarkdown, MAX_MARKDOWN_BYTES } from "./html-markdown";
import {
  formatWebfetchCall,
  rebuildWebfetchResultRenderComponent,
  WebfetchResultRenderComponent,
  type WebfetchDetails,
  type WebfetchRenderState,
} from "./render";

// ---------------------------------------------------------------------------
// Constants (mirrors OpenCode v2's webfetch.ts)
// ---------------------------------------------------------------------------

const MAX_RESPONSE_SIZE = MAX_MARKDOWN_BYTES; // 5MB, shared with renderer budget
const DEFAULT_TIMEOUT = 30 * 1000; // 30 seconds
const MAX_TIMEOUT_SECONDS = 120;

// ---------------------------------------------------------------------------
// Mime classification (mirrors OpenCode v2's webfetch.ts)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Accept header strategy (mirrors OpenCode v2 exactly)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Request identity (mirrors OpenCode v2's 0762d63b6)
//
// v2 sends an honest, bot-identifying UA by default (browser-shaped prefix to
// pass naive filters, compatible; token + contact URL to identify the client)
// and falls back to the bare client name on Cloudflare 403 challenges, where
// the spoofed browser shape fails the TLS-fingerprint check anyway.
// ---------------------------------------------------------------------------

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

/**
 * User-initiated cancellation.
 *
 * Classified by typed identity (`instanceof`), never by message text — the
 * error wrap must not let foreign errors impersonate a cancellation.
 */
export class RequestCancelledError extends Error {
  override name = "RequestCancelledError";
}

// ---------------------------------------------------------------------------
// HTTP fetch with Cloudflare retry (mirrors OpenCode v2)
//
// Differences from OpenCode:
// - Per-attempt AbortController (OpenCode uses Effect's runtime)
// - Drains response body on error to release TCP connections
// - Retry uses remaining timeout budget (OpenCode uses Effect.timeoutOrElse)
// ---------------------------------------------------------------------------

interface FetchResult {
  response: Response;
  arrayBuffer: ArrayBuffer;
}

async function fetchUrl(
  url: string,
  acceptHeader: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<FetchResult> {
  const fetchStartTime = Date.now();

  // Link external signal once for the entire operation (including retry)
  const externalController = new AbortController();
  if (signal?.aborted) externalController.abort();
  const onExternalAbort = () => externalController.abort();
  signal?.addEventListener("abort", onExternalAbort, { once: true });

  try {
    // --- First attempt: OpenCode-User UA ---
    const firstController = new AbortController();
    const firstTimeoutId = setTimeout(() => firstController.abort(), timeoutMs);
    const firstSignal = AbortSignal.any([externalController.signal, firstController.signal]);

    let response: Response;
    try {
      const headers = buildHeaders(acceptHeader, openCodeUserAgent);
      response = await fetch(url, {
        headers,
        signal: firstSignal,
        redirect: "follow",
      });
    } finally {
      clearTimeout(firstTimeoutId);
    }

    // --- Retry with bare client UA if blocked by Cloudflare bot detection ---
    // (TLS fingerprint mismatch with the browser-shaped default UA)
    if (response.status === 403 && response.headers.get("cf-mitigated") === "challenge") {
      // Drain the 403 response body to release the TCP connection back
      // to the pool before making a second request to the same origin.
      await response.arrayBuffer().catch(() => {});

      // Compute remaining time from the single total budget.
      // Mirrors OpenCode: Effect.timeoutOrElse wraps the entire operation
      // (including retry), so total wall time is bounded by timeoutMs.
      const retryDeadline = timeoutMs - (Date.now() - fetchStartTime);
      if (retryDeadline <= 0) {
        throw new Error(`Request timed out after ${timeoutMs / 1000}s`);
      }

      const retryController = new AbortController();
      const retryTimeoutId = setTimeout(() => retryController.abort(), retryDeadline);
      const retrySignal = AbortSignal.any([externalController.signal, retryController.signal]);

      try {
        const retryHeaders = buildHeaders(acceptHeader, CLOUDFLARE_RETRY_UA);
        response = await fetch(url, {
          headers: retryHeaders,
          signal: retrySignal,
          redirect: "follow",
        });
      } finally {
        clearTimeout(retryTimeoutId);
      }
    }

    // Check for HTTP errors — drain the body before throwing to release
    // the TCP connection back to Node's connection pool. Without this,
    // non-2xx responses (401, 404, 500, etc.) hold connections until GC.
    if (!response.ok) {
      await response.arrayBuffer().catch(() => {});
      throw new Error(`HTTP ${response.status} ${response.statusText}`);
    }

    // Check content length before downloading
    const contentLength = response.headers.get("content-length");
    if (contentLength && parseInt(contentLength, 10) > MAX_RESPONSE_SIZE) {
      throw new Error(`Response too large (exceeds ${MAX_RESPONSE_SIZE} byte limit)`);
    }

    const arrayBuffer = await response.arrayBuffer();
    if (arrayBuffer.byteLength > MAX_RESPONSE_SIZE) {
      throw new Error(`Response too large (exceeds ${MAX_RESPONSE_SIZE} byte limit)`);
    }

    return { response, arrayBuffer };
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

// ---------------------------------------------------------------------------
// Format conversion (mirrors OpenCode v2's convert helper)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tool schema (mirrors OpenCode v2's Input)
// ---------------------------------------------------------------------------

const WebFetchParamsSchema = Type.Object({
  url: Type.String({
    description: "The HTTP or HTTPS URL to fetch content from",
  }),
  format: Type.Optional(
    StringEnum(["text", "markdown", "html"] as const, {
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

// ---------------------------------------------------------------------------
// Tool description (v2's text; the managed-storage sentence adapted to this
// extension's pi-native truncation: full output goes to a temp file)
// ---------------------------------------------------------------------------

const DESCRIPTION = `Fetch content from an HTTP or HTTPS URL and return it as text, markdown, or HTML. Markdown is the default.

Use a more targeted tool when one is available. This tool is read-only. Large text results may be truncated while the complete output is saved to a temporary file.`;

// ---------------------------------------------------------------------------
// Temp file tracking for cleanup on session shutdown
// ---------------------------------------------------------------------------

const tempFiles: string[] = [];

async function cleanupTempFiles(): Promise<void> {
  const dirs = [...tempFiles];
  tempFiles.length = 0;
  const failed: string[] = [];
  for (const dir of dirs) {
    try {
      await rm(dir, { recursive: true, force: true });
    } catch (err: any) {
      console.warn(`[webfetch] Failed to clean up temp dir ${dir}:`, err.message || err);
      failed.push(dir);
    }
  }
  if (failed.length > 0) {
    tempFiles.push(...failed);
  }
}

// ---------------------------------------------------------------------------
// Extension entry
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  pi.on("session_shutdown", async () => {
    await cleanupTempFiles();
  });

  pi.registerTool({
    name: "webfetch",
    label: "Web Fetch",
    description: DESCRIPTION,
    parameters: WebFetchParamsSchema,

    async execute(
      _toolCallId,
      params,
      signal,
      onUpdate,
      _ctx,
    ): Promise<{
      content: Array<
        { type: "text"; text: string } | { type: "image"; data: string; mimeType: string }
      >;
      details: WebfetchDetails;
    }> {
      const format: "markdown" | "text" | "html" =
        (params.format as "markdown" | "text" | "html") ?? "markdown";
      // v2 fail-fast: the schema constrains timeout (0, 120]; the default
      // applies when the parameter is omitted.
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
        // --- Validate URL (mirrors v2's assertHttpUrl; a malformed URL throws
        //     TypeError from new URL and funnels to the error wrap below) ---
        const { protocol } = new URL(params.url);
        if (protocol !== "http:" && protocol !== "https:") {
          throw new Error("URL must use http:// or https://");
        }

        // --- Fetch ---
        const { response, arrayBuffer } = await fetchUrl(
          params.url,
          buildAcceptHeader(format),
          timeout,
          signal,
        );

        // --- Classify content type (mirrors v2's mimeFrom) ---
        const contentType = response.headers.get("content-type") || "";
        const mime = mimeFrom(contentType);
        details.contentType = contentType;

        // --- Image responses (pi-native keep; v2 fails on images) ---
        if (isImageAttachment(mime)) {
          const base64Content = Buffer.from(arrayBuffer).toString("base64");
          details.isImage = true;
          details.mime = mime;

          return {
            content: [
              { type: "text", text: "Image fetched successfully" },
              {
                type: "image",
                data: base64Content,
                mimeType: mime,
              },
            ],
            details,
          };
        }

        // --- Textual mime whitelist (mirrors v2's isTextualMime gate) ---
        if (!isTextualMime(mime)) {
          throw new Error(`Unsupported fetched file content type: ${mime}`);
        }

        // --- Decode and convert (mirrors v2's decode + convert) ---
        const content = new TextDecoder().decode(arrayBuffer);
        const output = convert(content, contentType, format);

        // --- Truncation (pi convention: bracket-format continuation notice) ---
        const truncation = truncateHead(output, {
          maxLines: DEFAULT_MAX_LINES,
          maxBytes: DEFAULT_MAX_BYTES,
        });

        let resultText = truncation.content;

        if (truncation.truncated) {
          const tempDir = await mkdtemp(join(tmpdir(), "pi-webfetch-"));
          const tempFile = join(tempDir, "output.txt");
          await writeFile(tempFile, output, "utf8");

          tempFiles.push(tempDir);

          details.truncation = truncation;
          details.fullOutputPath = tempFile;

          const startLine = 1;
          const endLine = truncation.outputLines;
          if (truncation.truncatedBy === "lines") {
            resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines}. Full output: ${tempFile}]`;
          } else {
            resultText += `\n\n[Showing lines ${startLine}-${endLine} of ${truncation.totalLines} (${formatSize(DEFAULT_MAX_BYTES)} limit). Full output: ${tempFile}]`;
          }
        }

        return {
          content: [{ type: "text", text: resultText }],
          details,
        };
      } catch (err) {
        // v2 error narrowing (367cf5961): everything surfaces as a single
        // message with the cause attached. User cancellations keep their
        // plain message (pi-native abort semantics), recognized by typed
        // identity — never by message text.
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
      );
      component.invalidate();
      return component;
    },
  });
}

// ---------------------------------------------------------------------------
// HTML → plain text (port of OpenCode v2's extractTextFromHTML; lives here
// like upstream, exported for tests)
// ---------------------------------------------------------------------------

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
