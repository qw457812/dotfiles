/**
 * Pi WebFetch Extension
 *
 * Adds a `webfetch` tool that fetches content from URLs and converts to
 * markdown, text, or HTML format.
 *
 * Mirrors OpenCode's webfetch implementation:
 * - URL validation (http/https only)
 * - Format parameter: markdown (default), text, or html
 * - Accept header strategy based on requested format
 * - User-Agent spoofing with Cloudflare retry
 * - Response body draining on error to release TCP connections
 * - Response size limit (5MB)
 * - Image handling (base64 for non-SVG, text for SVG)
 * - HTML→Markdown via TurndownService (same library as OpenCode)
 * - HTML→text via cheerio (mirrors HTMLRewriter skip behavior)
 * - Output truncation with temp file fallback
 * - No permission gate (unlike OpenCode which requires webfetch permission)
 */

import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  truncateHead,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { Type } from "typebox";

import { convertHtmlToMarkdown, extractTextFromHtml } from "./html-convert";
import {
  formatWebfetchCall,
  rebuildWebfetchResultRenderComponent,
  WebfetchResultRenderComponent,
  type WebfetchDetails,
  type WebfetchRenderState,
} from "./render";

// ---------------------------------------------------------------------------
// Constants (mirrors OpenCode's webfetch.ts)
// ---------------------------------------------------------------------------

const MAX_RESPONSE_SIZE = 5 * 1024 * 1024; // 5MB
const DEFAULT_TIMEOUT = 30 * 1000; // 30 seconds
const MAX_TIMEOUT = 120 * 1000; // 2 minutes

// ---------------------------------------------------------------------------
// Image type detection (mirrors OpenCode's util/media.ts)
// ---------------------------------------------------------------------------

function isImageAttachment(mime: string): boolean {
  return mime.startsWith("image/") && mime !== "image/svg+xml" && mime !== "image/vnd.fastbidsheet";
}

// ---------------------------------------------------------------------------
// Accept header strategy (mirrors OpenCode exactly)
// ---------------------------------------------------------------------------

function buildAcceptHeader(format: string): string {
  switch (format) {
    case "markdown":
      return "text/markdown;q=1.0, text/x-markdown;q=0.9, text/plain;q=0.8, text/html;q=0.7, */*;q=0.1";
    case "text":
      return "text/plain;q=1.0, text/markdown;q=0.9, text/html;q=0.8, */*;q=0.1";
    case "html":
      return "text/html;q=1.0, application/xhtml+xml;q=0.9, text/plain;q=0.8, text/markdown;q=0.7, */*;q=0.1";
    default:
      return "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8";
  }
}

// ---------------------------------------------------------------------------
// Common request headers (mirrors OpenCode's User-Agent spoofing)
// ---------------------------------------------------------------------------

const SPOOFED_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36";
const HONEST_UA = "opencode"; // mirrors OpenCode's retry UA

function buildHeaders(acceptHeader: string, userAgent: string): Record<string, string> {
  return {
    "User-Agent": userAgent,
    Accept: acceptHeader,
    "Accept-Language": "en-US,en;q=0.9",
  };
}

// ---------------------------------------------------------------------------
// HTTP fetch with Cloudflare retry (mirrors OpenCode)
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
    // --- First attempt: spoofed Chrome UA ---
    const firstController = new AbortController();
    const firstTimeoutId = setTimeout(() => firstController.abort(), timeoutMs);
    const firstSignal = AbortSignal.any([externalController.signal, firstController.signal]);

    let response: Response;
    try {
      const headers = buildHeaders(acceptHeader, SPOOFED_UA);
      response = await fetch(url, {
        headers,
        signal: firstSignal,
        redirect: "follow",
      });
    } finally {
      clearTimeout(firstTimeoutId);
    }

    // --- Retry with honest UA if blocked by Cloudflare bot detection ---
    // (TLS fingerprint mismatch with spoofed Chrome UA)
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
        const retryHeaders = buildHeaders(acceptHeader, HONEST_UA);
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
      throw new Error("Response too large (exceeds 5MB limit)");
    }

    const arrayBuffer = await response.arrayBuffer();
    if (arrayBuffer.byteLength > MAX_RESPONSE_SIZE) {
      throw new Error("Response too large (exceeds 5MB limit)");
    }

    return { response, arrayBuffer };
  } catch (err: any) {
    if (err.name === "AbortError") {
      if (signal?.aborted) {
        throw new Error("Request was cancelled");
      }
      throw new Error(`Request timed out after ${timeoutMs / 1000}s`);
    }
    throw err;
  } finally {
    signal?.removeEventListener("abort", onExternalAbort);
  }
}

// ---------------------------------------------------------------------------
// Tool schema (mirrors OpenCode's Parameters)
// ---------------------------------------------------------------------------

const WebFetchParamsSchema = Type.Object({
  url: Type.String({
    description: "The URL to fetch content from",
  }),
  format: Type.Optional(
    StringEnum(["text", "markdown", "html"] as const, {
      description:
        "The format to return the content in (text, markdown, or html). Defaults to markdown.",
    }),
  ),
  timeout: Type.Optional(
    Type.Number({
      description: "Optional timeout in seconds (max 120)",
    }),
  ),
});

// ---------------------------------------------------------------------------
// Tool description (adapted from OpenCode's webfetch.txt)
// ---------------------------------------------------------------------------

// TODO: shorten tool description, add promptSnippet/promptGuidelines if needed
// - https://www.npmjs.com/package/@ollama/pi-web-search?activeTab=code
// - https://github.com/juicesharp/rpiv-mono/blob/b4a2b7543b95d8d1e5a4d2e842bd9a09b555e225/packages/rpiv-web-tools/web-tools.ts
const DESCRIPTION = `- Fetches content from a specified URL
- Takes a URL and optional format as input
- Fetches the URL content, converts to requested format (markdown by default)
- Returns the content in the specified format
- Use this tool when you need to retrieve and analyze web content

Usage notes:
  - IMPORTANT: if another tool is present that offers better web fetching capabilities, is more targeted to the task, or has fewer restrictions, prefer using that tool instead of this one.
  - The URL must be a fully-formed valid URL
  - Format options: "markdown" (default), "text", or "html"
  - This tool is read-only and does not modify any files`;

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
      // --- Validate URL ---
      if (!params.url.startsWith("http://") && !params.url.startsWith("https://")) {
        throw new Error("URL must start with http:// or https://");
      }

      const format: "markdown" | "text" | "html" =
        (params.format as "markdown" | "text" | "html") ?? "markdown";
      // --- Timeout: clamp min 1s, max 120s (mirrors OpenCode's limits) ---
      const timeout = Math.max(
        1000,
        Math.min((params.timeout ?? DEFAULT_TIMEOUT / 1000) * 1000, MAX_TIMEOUT),
      );

      const details: WebfetchDetails = {
        url: params.url,
        format,
      };

      // --- Progress update ---
      onUpdate?.({
        content: [{ type: "text", text: `Fetching ${params.url}...` }],
        details,
      });

      // --- Build Accept header ---
      const acceptHeader = buildAcceptHeader(format);

      // --- Fetch ---
      const { response, arrayBuffer } = await fetchUrl(params.url, acceptHeader, timeout, signal);

      // --- Parse content type ---
      const contentType = response.headers.get("content-type") || "";
      const mime = contentType.split(";")[0]?.trim().toLowerCase() || "";
      details.contentType = contentType;

      // --- Handle image responses ---
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

      // --- Decode text content ---
      const content = new TextDecoder().decode(arrayBuffer);

      // --- Format conversion (mirrors OpenCode's switch on format + contentType) ---
      let output: string;

      switch (format) {
        case "markdown":
          if (contentType.includes("text/html")) {
            output = convertHtmlToMarkdown(content);
          } else {
            output = content;
          }
          break;

        case "text":
          if (contentType.includes("text/html")) {
            output = extractTextFromHtml(content);
          } else {
            output = content;
          }
          break;

        case "html":
          output = content;
          break;

        default:
          output = content;
      }

      // --- Truncation (mirrors websearch extension) ---
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

        const truncatedLines = truncation.totalLines - truncation.outputLines;

        resultText += `\n\n...${truncatedLines} lines truncated...\n\nThe tool call succeeded but the output was truncated. Full output saved to: ${tempFile}\nUse bash with rg to search the full content or read with offset/limit to view specific sections.`;
      }

      return {
        content: [{ type: "text", text: resultText }],
        details,
      };
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
