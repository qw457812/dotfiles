// Golden checks for the webfetch mirror — ports the assertions of OpenCode
// v2's packages/core/test/tool-webfetch.test.ts and
// tool-html-markdown-budget.test.ts (conversions, inline-code boundaries,
// byte-budget edge cases) onto the mirror's plain-function architecture.
//
// Run: node private_dot_pi/private_agent/extensions/tests/webfetch-golden.mjs
import { check, equal, loadTs, summary } from "./helpers.mjs";

const { convertHTMLToMarkdown, MAX_MARKDOWN_BYTES } = await loadTs("../webfetch/html-markdown.ts");
const { extractTextFromHTML } = await loadTs("../webfetch/index.ts");

// tool-webfetch.test.ts: "defaults to the production byte budget …"
equal("production byte budget (5MB)", MAX_MARKDOWN_BYTES, 5 * 1024 * 1024);
const budget = MAX_MARKDOWN_BYTES - 64 * 1024;

// --- conversions -----------------------------------------------------------
// tool-webfetch.test.ts: "ports HTML text and markdown conversions without
// active content"
{
  const html =
    "<h1>Hello</h1><script>bad()</script><p>world <strong>wide</strong> <product-name>today</product-name></p><style>.bad {}</style>";
  equal(
    "text conversion without active content",
    extractTextFromHTML(html),
    "Helloworld wide today",
  );
  equal(
    "markdown conversion without active content",
    convertHTMLToMarkdown(html),
    "# Hello\n\nworld **wide** today",
  );
}

// tool-webfetch.test.ts: "renders headings, inline semantics, links, images,
// breaks, and thematic breaks"
{
  const html = `<h2>Read <em>this</em></h2><p><a href="https://example.com/a (b)" title="Example">docs</a><br><img src="diagram.png" alt="a ] b"></p><hr><p><del>old</del></p>`;
  equal(
    "headings, inline semantics, links, images, breaks",
    convertHTMLToMarkdown(html),
    `## Read *this*\n\n[docs](https://example.com/a%20\\(b\\) "Example")  \n![a \\] b](diagram.png)\n\n---\n\n~~old~~`,
  );
}

// tool-webfetch.test.ts: "preserves inline and preformatted code verbatim with
// safe fences"
{
  const html = `<p>Use <code>say(\`hello\`)</code> now.</p><pre><code class="language-ts">const fence = \`\`\`\n&amp; stays decoded</code></pre>`;
  equal(
    "inline and preformatted code with safe fences",
    convertHTMLToMarkdown(html),
    "Use ``say(`hello`)`` now.\n\n~~~ts\nconst fence = ```\n& stays decoded\n~~~",
  );
}

// --- inline-code boundaries ------------------------------------------------
// tool-webfetch.test.ts: "preserves inline code boundaries for %j"
for (const [content, expected] of [
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
]) {
  equal(
    `inline code boundary ${JSON.stringify(content)}`,
    convertHTMLToMarkdown(`<p>Use <code>${content}</code>.</p>`),
    `Use ${expected}.`,
  );
}

// --- byte-budget edge cases ------------------------------------------------
// tool-webfetch.test.ts: "fits inline code to its emitted boundaries: %s"
for (const [name, content, spare, expected] of [
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
]) {
  const prefix = "x".repeat(budget - spare);
  const html = `<p>${prefix}<code>${content}</code></p>`;
  check(`${name}: input fits the budget`, Buffer.byteLength(html) <= MAX_MARKDOWN_BYTES);
  const output = convertHTMLToMarkdown(html);
  check(
    `budget fit: ${name}`,
    output.slice(0, prefix.length) === prefix && output.slice(prefix.length) === expected,
    { tail: output.slice(prefix.length) },
  );
}

// tool-html-markdown-budget.test.ts: "finishes bounded code conversion: %s"
for (const [name, count, payload, suffix, quoted] of [
  ["exhausted budget", budget, "x", "", false],
  ["one byte short of an empty fence", budget - 13, "x", "", false],
  ["small fitting block", 64, "x", "\n\n```\nx\n```", false],
  ["last payload byte fits", budget - 15, "x", "\n\n```\nx\n```", false],
  ["only an empty fence fits", budget - 14, "x", "\n\n```\n\n```", false],
  ["Unicode payload truncates at a code point", budget - 18, "😀é", "\n\n```\n😀\n```", false],
  ["quoted payload fits", budget - 23, "x", "\n\n> ```\n> x\n> ```", true],
  ["only an empty quoted fence fits", budget - 22, "x", "\n\n> ```\n> \n> ```", true],
  ["one byte short of an empty quoted fence", budget - 21, "x", "", true],
]) {
  const code = `<pre>${payload}</pre>`;
  const html = `<p>${"x".repeat(count)}</p>${quoted ? `<blockquote>${code}</blockquote>` : code}`;
  equal(
    `bounded code conversion: ${name}`,
    convertHTMLToMarkdown(html),
    "x".repeat(Math.min(count, budget - 2)) + suffix,
  );
}

process.exit(summary("webfetch golden") ? 1 : 0);
