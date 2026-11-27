// Golden checks ported from OpenCode's tool-webfetch and HTML Markdown budget tests.
import { afterEach, describe, expect, it, vi } from "vitest";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { convertHTMLToMarkdown, MAX_MARKDOWN_BYTES } from "../html-markdown";
import webfetch, { extractTextFromHTML, MAX_REDIRECTS, RequestCancelledError } from "../index";

async function captureError(promise: Promise<unknown>): Promise<any> {
  try {
    await promise;
  } catch (err) {
    return err;
  }
  throw new Error("expected the call to fail, but it resolved");
}

// The renderer reserves 64 KiB for closing Markdown structures.
const budget = MAX_MARKDOWN_BYTES - 64 * 1024;

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

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

  it("renders headings, inline semantics, links, images, breaks, and thematic breaks", () => {
    const input = `<h2>Read <em>this</em></h2><p><a href="https://example.com/a (b)" title="Example">docs</a><br><img src="diagram.png" alt="a ] b"></p><hr><p><del>old</del></p>`;
    expect(convertHTMLToMarkdown(input)).toBe(
      `## Read *this*\n\n[docs](https://example.com/a%20\\(b\\) "Example")  \n![a \\] b](diagram.png)\n\n---\n\n~~old~~`,
    );
  });

  it("preserves inline and preformatted code verbatim with safe fences", () => {
    const input = `<p>Use <code>say(\`hello\`)</code> now.</p><pre><code class="language-ts">const fence = \`\`\`\n&amp; stays decoded</code></pre>`;
    expect(convertHTMLToMarkdown(input)).toBe(
      "Use ``say(`hello`)`` now.\n\n~~~ts\nconst fence = ```\n& stays decoded\n~~~",
    );
  });
});

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

describe("full-output temp-file failure", () => {
  it("keeps the truncated output and says why the full output was not saved", async () => {
    const missing = join(tmpdir(), "pi-webfetch-missing-temp-dir");
    vi.stubEnv("TMPDIR", missing);
    vi.stubEnv("TMP", missing);
    vi.stubEnv("TEMP", missing);
    const tool = activateWebfetch(
      () => new Response("line\n".repeat(3000), { headers: { "content-type": "text/plain" } }),
    );

    const out = await tool.run();

    expect(out.details.truncation.truncated).toBe(true);
    expect(out.details.fullOutputPath).toBeUndefined();
    expect(out.details.fullOutputError).toMatch(/ENOENT/);
    expect(out.structuredContent).toEqual({
      contentType: "text/plain",
      output: "line\n".repeat(3000),
    });
    expect(out.content[0].text).toMatch(/^line\n/);
    expect(out.content[0].text).toMatch(
      /\[Showing lines 1-2000 of \d+\. Could not save the full output: ENOENT/,
    );
  });
});

describe("structured output and media types", () => {
  it("returns the response MIME and converted text", async () => {
    const tool = activateWebfetch(
      () =>
        new Response("<p>Hello <strong>world</strong></p>", {
          headers: { "content-type": "text/html; charset=utf-8" },
        }),
    );

    const out = await tool.run();

    expect(out.content).toEqual([{ type: "text", text: "Hello **world**" }]);
    expect(out.structuredContent).toEqual({
      contentType: "text/html; charset=utf-8",
      output: "Hello **world**",
    });
  });

  it("rejects binary images", async () => {
    const tool = activateWebfetch(
      () =>
        new Response(new Uint8Array([137, 80, 78, 71]), {
          headers: { "content-type": "image/png" },
        }),
    );

    await expect(tool.run()).rejects.toThrow("Unsupported fetched image content type: image/png");
  });

  it("returns SVG as text", async () => {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg"><circle r="3"/></svg>';
    const tool = activateWebfetch(
      () => new Response(svg, { headers: { "content-type": "image/svg+xml" } }),
    );

    const out = await tool.run();

    expect(out.content).toEqual([{ type: "text", text: svg }]);
    expect(out.structuredContent).toEqual({ contentType: "image/svg+xml", output: svg });
  });
});

function activateWebfetch(
  fetchImpl: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
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
    run: (signal?: AbortSignal, overrides: Record<string, unknown> = {}) =>
      tool.execute(
        "call-1",
        { url: "https://example.com/x", format: "markdown", ...overrides },
        signal,
        undefined,
        {},
      ),
    fetchMock,
  };
}

describe("request errors", () => {
  it("reports ordinary 403s with the upstream status message and does not retry", async () => {
    const tool = activateWebfetch(
      () => new Response("remote body", { status: 403, statusText: "remote status text" }),
    );

    const err = await captureError(tool.run());

    expect(err.message).toBe("StatusCode: non 2xx status code (403 GET https://example.com/x)");
    expect(tool.fetchMock).toHaveBeenCalledTimes(1);
  });

  it("reports the failed request URL after following a redirect", async () => {
    const tool = activateWebfetch((url) =>
      url.endsWith("/x") ? redirect("/missing#fragment") : new Response(null, { status: 404 }),
    );

    const err = await captureError(tool.run());

    expect(err.message).toBe(
      "StatusCode: non 2xx status code (404 GET https://example.com/missing)",
    );
  });

  it("reports a request timeout", async () => {
    vi.useFakeTimers();
    try {
      const tool = activateWebfetch(
        (_url, { signal } = {}) =>
          new Promise<Response>((_resolve, reject) => {
            signal?.addEventListener("abort", () => reject(signal.reason), { once: true });
          }),
      );
      const failure = captureError(tool.run(undefined, { timeout: 1 }));
      await vi.advanceTimersByTimeAsync(1000);
      expect((await failure).message).toBe("Request timed out");
    } finally {
      vi.useRealTimers();
    }
  });

  it("uses one deadline for the initial request, Cloudflare retry, and final body", async () => {
    vi.useFakeTimers();
    try {
      const cancel = vi.fn();
      const tool = activateWebfetch(async (_url, init) => {
        if (new Headers(init?.headers).get("User-Agent") !== "opencode") {
          await new Promise((resolve) => setTimeout(resolve, 750));
          return new Response(new ReadableStream({ pull() {} }), {
            status: 403,
            headers: { "cf-mitigated": "challenge" },
          });
        }
        return new Response(new ReadableStream({ pull() {}, cancel }));
      });

      const failure = captureError(tool.run(undefined, { timeout: 1 }));
      await vi.advanceTimersByTimeAsync(1000);
      expect(tool.fetchMock).toHaveBeenCalledTimes(2);
      expect(cancel).toHaveBeenCalledTimes(1);
      expect((await failure).message).toBe("Request timed out");
    } finally {
      vi.useRealTimers();
    }
  });

  it("reports the declared response size limit", async () => {
    const tool = activateWebfetch(
      () => new Response("", { headers: { "content-length": String(MAX_MARKDOWN_BYTES + 1) } }),
    );

    await expect(tool.run()).rejects.toThrow(
      `Response too large (exceeds ${MAX_MARKDOWN_BYTES} byte limit)`,
    );
  });

  it("cancels an oversized streamed response without waiting for EOF", async () => {
    const cancel = vi.fn();
    const tool = activateWebfetch(
      () =>
        new Response(
          new ReadableStream({
            start(controller) {
              controller.enqueue(new Uint8Array(MAX_MARKDOWN_BYTES));
              controller.enqueue(new Uint8Array(1));
            },
            cancel,
          }),
        ),
    );

    await expect(tool.run()).rejects.toThrow(
      `Response too large (exceeds ${MAX_MARKDOWN_BYTES} byte limit)`,
    );
    expect(cancel).toHaveBeenCalledTimes(1);
  });

  it("does not echo a malformed remote MIME value", async () => {
    const tool = activateWebfetch(
      () => new Response("", { headers: { "content-type": "application/not a media type" } }),
    );

    const err = await captureError(tool.run());

    expect(err.message).toBe("Unsupported fetched file content type");
  });
});

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

  it("preserves user cancellation during a stalled body read", async () => {
    const cancel = vi.fn();
    const controller = new AbortController();
    const tool = activateWebfetch(() => new Response(new ReadableStream({ pull() {}, cancel })));
    const failure = captureError(tool.run(controller.signal));
    await new Promise((resolve) => setTimeout(resolve, 0));
    controller.abort();

    expect(await failure).toBeInstanceOf(RequestCancelledError);
    expect(cancel).toHaveBeenCalledTimes(1);
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

// Port the URL validation assertions; OpenCode's permission rules have no local equivalent.

const redirect = (location: string, status = 302) =>
  new Response(null, { status, headers: { location } });

const ok = () => new Response("hello", { headers: { "content-type": "text/plain" } });

describe("redirects and URL validation", () => {
  it("follows redirects manually and resolves relative targets", async () => {
    const seen: Array<{ url: string; redirect?: string }> = [];
    const tool = activateWebfetch((url, init) => {
      seen.push({ url, redirect: init?.redirect });
      if (url === "https://example.com/x") return redirect("/target");
      if (url === "https://example.com/target")
        return redirect("https://cdn.example.com/final#frag", 301);
      return ok();
    });

    const result = await tool.run();

    expect(seen).toEqual([
      { url: "https://example.com/x", redirect: "manual" },
      { url: "https://example.com/target", redirect: "manual" },
      { url: "https://cdn.example.com/final", redirect: "manual" },
    ]);
    expect(result.content).toEqual([{ type: "text", text: "hello" }]);
    expect(result.details).toMatchObject({
      url: "https://example.com/x",
      contentType: "text/plain",
    });
  });

  it("strips the fragment from the requested URL", async () => {
    const seen: string[] = [];
    const tool = activateWebfetch((url) => {
      seen.push(url);
      return ok();
    });

    await tool.run(undefined, { url: "https://Example.com/page#top" });

    expect(seen).toEqual(["https://Example.com/page"]);
  });

  it("rejects credentials before transport", async () => {
    const tool = activateWebfetch(ok);

    const err = await captureError(tool.run(undefined, { url: "https://user@example.com/" }));

    expect(err.message).toBe("URL must not include credentials");
    expect(tool.fetchMock).not.toHaveBeenCalled();
  });

  it("reports malformed URLs before transport", async () => {
    const tool = activateWebfetch(ok);

    await expect(tool.run(undefined, { url: "not a URL" })).rejects.toThrow("Invalid URL");
    expect(tool.fetchMock).not.toHaveBeenCalled();
  });

  it("reports a malformed redirect URL", async () => {
    const tool = activateWebfetch(() => redirect("http://["));

    await expect(tool.run()).rejects.toThrow("Invalid URL");
    expect(tool.fetchMock).toHaveBeenCalledTimes(1);
  });

  it("rejects redirects to non-HTTP schemes", async () => {
    const tool = activateWebfetch(() => redirect("file:///etc/passwd"));

    const err = await captureError(tool.run());

    expect(err.message).toBe("URL must use http:// or https://");
    expect(tool.fetchMock).toHaveBeenCalledTimes(1);
  });

  it("rejects redirects that include credentials", async () => {
    const tool = activateWebfetch(() => redirect("https://user@evil.example.com/"));

    const err = await captureError(tool.run());

    expect(err.message).toBe("URL must not include credentials");
    expect(tool.fetchMock).toHaveBeenCalledTimes(1);
  });

  it("stops endless redirect chains", async () => {
    const tool = activateWebfetch((url) => redirect(`${url}x`, 307));

    const err = await captureError(tool.run());

    expect(err.message).toBe(`Too many redirects (more than ${MAX_REDIRECTS})`);
    expect(tool.fetchMock).toHaveBeenCalledTimes(MAX_REDIRECTS + 1);
  });

  it("keeps the Cloudflare retry, restarting the redirect chain", async () => {
    const seen: Array<{ url: string; userAgent: string }> = [];
    const tool = activateWebfetch((url, init) => {
      const headers = (init?.headers as Record<string, string> | undefined) ?? {};
      const userAgent = headers["User-Agent"] ?? "";
      seen.push({ url, userAgent });
      if (url === "https://example.com/x") return redirect("/target");
      if (userAgent === "opencode") return ok();
      return new Response(null, { status: 403, headers: { "cf-mitigated": "challenge" } });
    });

    await tool.run();

    expect(seen.map((entry) => entry.url)).toEqual([
      "https://example.com/x",
      "https://example.com/target",
      "https://example.com/x",
      "https://example.com/target",
    ]);
    expect(seen.map((entry) => entry.userAgent === "opencode")).toEqual([false, false, true, true]);
  });
});
