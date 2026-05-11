/**
 * HTML to Markdown / plain-text conversion utilities.
 *
 * Mirrors OpenCode's two conversion paths:
 * 1. convertHtmlToMarkdown — uses TurndownService (same library as OpenCode)
 *    with matching options:
 *    - headingStyle: "atx"  →  # heading
 *    - hr: "---"
 *    - bulletListMarker: "-"
 *    - codeBlockStyle: "fenced"  →  ``` ... ```
 *    - emDelimiter: "*"
 *    - removes: script, style, meta, link
 *
 * 2. extractTextFromHtml — uses cheerio (DOM-based, replaces regex approach)
 *    with matching skip list:
 *    - skips: script, style, noscript, iframe, object, embed
 *    - extracts text from remaining elements
 */

import TurndownService from "turndown";
import * as cheerio from "cheerio";

// ---------------------------------------------------------------------------
// HTML → Markdown (mirrors OpenCode's convertHTMLToMarkdown exactly)
// ---------------------------------------------------------------------------

/**
 * Convert HTML to Markdown using TurndownService.
 * Creates a fresh instance per call to match OpenCode's per-call pattern
 * and avoid cross-request state leakage from custom rules/plugins.
 */
export function convertHtmlToMarkdown(html: string): string {
  const turndownService = new TurndownService({
    headingStyle: "atx",
    hr: "---",
    bulletListMarker: "-",
    codeBlockStyle: "fenced",
    emDelimiter: "*",
  });
  turndownService.remove(["script", "style", "meta", "link"]);
  return turndownService.turndown(html);
}

// ---------------------------------------------------------------------------
// HTML → plain text (uses cheerio, mirrors Cloudflare HTMLRewriter behavior)
// ---------------------------------------------------------------------------

/**
 * Extract plain text from HTML using cheerio.
 * Mirrors OpenCode's extractTextFromHTML which uses Cloudflare HTMLRewriter
 * to skip script/style/noscript/iframe/object/embed elements.
 *
 * OpenCode's HTMLRewriter only skips text *inside* blocked elements —
 * it does not remove sibling text after those elements. We match that
 * behavior with simple .remove() on all skip tags.
 */
export function extractTextFromHtml(html: string): string {
  const $ = cheerio.load(html);
  $("script, style, noscript, iframe, object, embed").remove();
  return $.text().trim();
}
