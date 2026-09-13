import { Readability } from "@mozilla/readability";
import { parseHTML } from "linkedom";
import { getDocumentProxy } from "unpdf";

import { convertHtmlToMarkdown } from "./html-convert";

const MIN_USEFUL_CONTENT = 500;
const JINA_READER_BASE = "https://r.jina.ai/";

export interface PdfExtraction {
  content: string;
  pages: number;
  title: string;
}

export function isPdf(url: string, contentType: string): boolean {
  if (contentType.toLowerCase().includes("application/pdf")) return true;
  try {
    return new URL(url).pathname.toLowerCase().endsWith(".pdf");
  } catch {
    return false;
  }
}

export async function extractPdf(arrayBuffer: ArrayBuffer, url: string): Promise<PdfExtraction> {
  const pdf = await getDocumentProxy(new Uint8Array(arrayBuffer));
  const metadata = await pdf.getMetadata();
  const info =
    metadata.info && typeof metadata.info === "object"
      ? (metadata.info as Record<string, unknown>)
      : {};
  const fallbackTitle = decodeURIComponent(
    new URL(url).pathname.split("/").pop() || "document.pdf",
  ).replace(/\.pdf$/i, "");
  const title = (typeof info.Title === "string" && info.Title.trim()) || fallbackTitle;
  const author = typeof info.Author === "string" ? info.Author.trim() : "";
  const lines = [`# ${title}`, "", `> Source: ${url}`, `> Pages: ${pdf.numPages}`];
  if (author) lines.push(`> Author: ${author}`);

  for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber++) {
    const page = await pdf.getPage(pageNumber);
    const textContent = await page.getTextContent();
    const text = textContent.items
      .map((item: unknown) => (item as { str?: string }).str || "")
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
    lines.push("", `<!-- Page ${pageNumber} -->`, "", text);
  }

  return { content: lines.join("\n"), pages: pdf.numPages, title };
}

export function extractReadableMarkdown(html: string): { content: string; title: string } | null {
  const { document } = parseHTML(html);
  const article = new Readability(document as unknown as Document).parse();
  if (!article?.content) return null;
  const content = convertHtmlToMarkdown(article.content).trim();
  if (!content) return null;
  return { content, title: article.title || "" };
}

export function isUsefulContent(content: string): boolean {
  const normalized = content.replace(/\s+/g, " ").trim();
  if (normalized.length < MIN_USEFUL_CONTENT) return false;
  return !/(doesn't work properly without JavaScript|please enable JavaScript|enable it to continue)/i.test(
    normalized,
  );
}

export async function fetchWithJina(
  url: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<string | null> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(`${JINA_READER_BASE}${url}`, {
      headers: { Accept: "text/markdown", "X-No-Cache": "true" },
      signal: AbortSignal.any([controller.signal, ...(signal ? [signal] : [])]),
    });
    if (!response.ok) return null;
    const content = await response.text();
    const marker = "Markdown Content:";
    const markerIndex = content.indexOf(marker);
    const markdown = (
      markerIndex >= 0 ? content.slice(markerIndex + marker.length) : content
    ).trim();
    return isUsefulContent(markdown) ? markdown : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timeoutId);
  }
}
