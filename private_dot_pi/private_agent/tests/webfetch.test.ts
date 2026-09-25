// Golden checks for the webfetch mirror — ports the assertions of OpenCode
// v2's packages/core/test/tool-webfetch.test.ts and
// tool-html-markdown-budget.test.ts (conversions, inline-code boundaries,
// byte-budget edge cases) onto the mirror's plain-function architecture.
//
// Run: npm --prefix private_dot_pi/private_agent test -- webfetch
import { afterEach, describe, expect, it, vi } from "vitest";

import { convertHTMLToMarkdown, MAX_MARKDOWN_BYTES } from "../extensions/webfetch/html-markdown";
import webfetch, { extractTextFromHTML, RequestCancelledError } from "../extensions/webfetch/index";

/** Await a promise that must reject, and return the rejection value. */
async function captureError(promise: Promise<unknown>): Promise<any> {
  try {
    await promise;
  } catch (err) {
    return err;
  }
  throw new Error("expected the call to fail, but it resolved");
}

// tool-webfetch.test.ts: "defaults to the production byte budget …"
const budget = MAX_MARKDOWN_BYTES - 64 * 1024;

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

// --- conversions -----------------------------------------------------------

// tool-webfetch.test.ts: "ports HTML text and markdown conversions without
// active content"
describe("conversions", () => {
  const html =
    "<h1>Hello</h1><script>bad()</script><p>world <strong>wide</strong> <product-name>today</product-name></p><style>.bad {}</style>";

  it("defaults to the production byte budget", () => {
    expect(MAX_MARKDOWN_BYTES).toBe(5 * 1024 * 1024);
  });

  it("ports text and markdown conversions without active content", () => {
    expect(extractTextFromHTML(html)).toBe("Helloworld wide today");
    expect(convertHTMLToMarkdown(html)).toBe("# Hello\n\nworld **wide** today");
  });

  // tool-webfetch.test.ts: "renders headings, inline semantics, links, images,
  // breaks, and thematic breaks"
  it("renders headings, inline semantics, links, images, breaks, and thematic breaks", () => {
    const input = `<h2>Read <em>this</em></h2><p><a href="https://example.com/a (b)" title="Example">docs</a><br><img src="diagram.png" alt="a ] b"></p><hr><p><del>old</del></p>`;
    expect(convertHTMLToMarkdown(input)).toBe(
      `## Read *this*\n\n[docs](https://example.com/a%20\\(b\\) "Example")  \n![a \\] b](diagram.png)\n\n---\n\n~~old~~`,
    );
  });

  // tool-webfetch.test.ts: "preserves inline and preformatted code verbatim
  // with safe fences"
  it("preserves inline and preformatted code verbatim with safe fences", () => {
    const input = `<p>Use <code>say(\`hello\`)</code> now.</p><pre><code class="language-ts">const fence = \`\`\`\n&amp; stays decoded</code></pre>`;
    expect(convertHTMLToMarkdown(input)).toBe(
      "Use ``say(`hello`)`` now.\n\n~~~ts\nconst fence = ```\n& stays decoded\n~~~",
    );
  });
});

// --- inline-code boundaries ------------------------------------------------

// tool-webfetch.test.ts: "preserves inline code boundaries for %j"
const inlineBoundaries: Array<[string, string]> = [
  ["`x`", "`` `x` ``"],
  ["`x", "`` `x ``"],
  ["x`", "`` x` ``"],
  ["`", "`` ` ``"],
  ["``", "``` `` ```"],
  ["``x`", "``` ``x` ```"],
  ["say(`x`)", "``say(`x`)``"],
  ["a``b`c", "```a``b`c```"],
  ["x", "`x`"],
  [" x ", "`  x  `"],
  [" x", "`  x `"],
  ["x ", "` x  `"],
  ["   ", "`   `"],
  [" ` ", "``  `  ``"],
];

describe("inline-code boundaries", () => {
  it.each(inlineBoundaries)("preserves inline code boundaries for %j", (content, expected) => {
    expect(convertHTMLToMarkdown(`<p>Use <code>${content}</code>.</p>`)).toBe(`Use ${expected}.`);
  });
});

// --- byte-budget edge cases ------------------------------------------------

// tool-webfetch.test.ts: "fits inline code to its emitted boundaries: %s"
const budgetFits: Array<[string, string, number, string]> = [
  ["discarded trailing backtick after ASCII", "x`", 7, "``x``"],
  ["discarded trailing backtick after Unicode", "😀`", 10, "``😀``"],
  ["discarded trailing backtick with spare room", "x`", 9, "``x``"],
  ["retained trailing backtick", "x`", 10, "`` x` ``"],
  ["new trailing backtick from an internal run", "x`y", 8, "``x``"],
  ["leading backtick without padding room", "`x", 8, ""],
  ["leading backtick alone fits", "`x", 9, "`` ` ``"],
  ["leading backtick with payload fits", "`x", 10, "`` `x ``"],
  ["all backticks truncated", "``", 11, "``` ` ```"],
  ["all backticks fit", "``", 12, "``` `` ```"],
  ["mixed internal runs truncated", "a``b`c", 11, "```a```"],
  ["Unicode code point cannot fit", "😀`", 9, ""],
  ["ordinary payload cannot fit", "x", 3, ""],
  ["spaces cannot fit", "   ", 4, ""],
  ["space-only prefix fits", "   ", 5, "` `"],
  ["truncated prefix becomes space-only", " x", 6, "` `"],
  ["discarded trailing space", "x ", 5, "`x`"],
];

describe("byte-budget edge cases", () => {
  it.each(budgetFits)(
    "fits inline code to its emitted boundaries: %s",
    (_name, content, spare, expected) => {
      const prefix = "x".repeat(budget - spare);
      const html = `<p>${prefix}<code>${content}</code></p>`;
      expect(Buffer.byteLength(html)).toBeLessThanOrEqual(MAX_MARKDOWN_BYTES);
      const output = convertHTMLToMarkdown(html);
      expect(output.slice(0, prefix.length)).toBe(prefix);
      expect(output.slice(prefix.length)).toBe(expected);
    },
  );

  // tool-html-markdown-budget.test.ts: "finishes bounded code conversion: %s"
  const codeBudgets: Array<[string, number, string, string, boolean]> = [
    ["exhausted budget", budget, "x", "", false],
    ["one byte short of an empty fence", budget - 13, "x", "", false],
    ["small fitting block", 64, "x", "\n\n```\nx\n```", false],
    ["last payload byte fits", budget - 15, "x", "\n\n```\nx\n```", false],
    ["only an empty fence fits", budget - 14, "x", "\n\n```\n\n```", false],
    ["Unicode payload truncates at a code point", budget - 18, "😀é", "\n\n```\n😀\n```", false],
    ["quoted payload fits", budget - 23, "x", "\n\n> ```\n> x\n> ```", true],
    ["only an empty quoted fence fits", budget - 22, "x", "\n\n> ```\n> \n> ```", true],
    ["one byte short of an empty quoted fence", budget - 21, "x", "", true],
  ];

  it.each(codeBudgets)(
    "finishes bounded code conversion: %s",
    (_name, count, payload, suffix, quoted) => {
      const code = `<pre>${payload}</pre>`;
      const html = `<p>${"x".repeat(count)}</p>${quoted ? `<blockquote>${code}</blockquote>` : code}`;
      expect(convertHTMLToMarkdown(html)).toBe("x".repeat(Math.min(count, budget - 2)) + suffix);
    },
  );
});

// --- cancellation identity -------------------------------------------------
// Companion guard for the websearch finding: cancellation is recognized by
// typed identity (RequestCancelledError), never by message text.

function activateWebfetch(fetchImpl: (url: string) => Response) {
  let tool: any;
  webfetch({
    on() {},
    registerTool(definition: any) {
      tool = definition;
    },
    appendEntry() {},
  } as unknown as Parameters<typeof webfetch>[0]);
  const fetchMock = vi.fn(fetchImpl);
  vi.stubGlobal("fetch", fetchMock);
  return {
    run: (signal?: AbortSignal) =>
      tool.execute(
        "call-1",
        { url: "https://example.com/x", format: "markdown" },
        signal,
        undefined,
        {},
      ),
    fetchMock,
  };
}

describe("cancellation identity", () => {
  it("keeps its plain message for user cancellation", async () => {
    const tool = activateWebfetch(() => {
      throw Object.assign(new Error("The operation was aborted"), { name: "AbortError" });
    });
    const controller = new AbortController();
    controller.abort();
    const err = await captureError(tool.run(controller.signal));
    expect(err).toBeInstanceOf(RequestCancelledError);
    expect(err.message).toBe("Request was cancelled");
  });

  it("wraps foreign errors that imitate the cancellation message", async () => {
    const tool = activateWebfetch(() => {
      throw new Error("Request was cancelled");
    });
    const err = await captureError(tool.run());
    expect(err.message).toBe("Unable to fetch https://example.com/x");
    expect(err.cause.message).toBe("Request was cancelled");
  });
});
