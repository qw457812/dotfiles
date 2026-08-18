import { describe, expect, test } from "vitest";
import { parseCommandArgs, parsePromptFile, substituteArgs } from "../src/prompt-templates.js";

describe("parsePromptFile", () => {
  test("supports quoted, escaped, colon, and block YAML scalars", () => {
    const quoted = parsePromptFile(String.raw`---
description: "Say \"hi\": clearly"
argument-hint: "topic: detail"
---
Prompt body`);
    expect(quoted).toEqual({
      meta: { description: 'Say "hi": clearly', "argument-hint": "topic: detail" },
      body: "Prompt body",
    });

    const block = parsePromptFile(
      ["---", "description: |", "  First line", "  Second: line", "---", "Body"].join("\n"),
    );
    expect(block.meta.description).toBe("First line\nSecond: line\n");
    expect(block.body).toBe("Body");
  });

  test("normalizes newlines and preserves missing or incomplete frontmatter", () => {
    expect(parsePromptFile("plain\r\nbody\r")).toEqual({ meta: {}, body: "plain\nbody\n" });
    expect(parsePromptFile("---\r\ndescription: value\r\nbody")).toEqual({
      meta: {},
      body: "---\ndescription: value\nbody",
    });
  });

  test("returns an empty mapping for comment-only frontmatter", () => {
    expect(parsePromptFile("---\n# comment\n---\nBody")).toEqual({ meta: {}, body: "Body" });
  });

  test("propagates malformed YAML for per-file diagnostics", () => {
    expect(() => parsePromptFile("---\ndescription: [broken\n---\nBody")).toThrow();
  });
});

describe("parseCommandArgs", () => {
  test.each([
    ["empty input", "", []],
    ["plain words", "alpha beta", ["alpha", "beta"]],
    ["double quotes", 'alpha "two words"', ["alpha", "two words"]],
    ["single quotes", "alpha 'two words'", ["alpha", "two words"]],
    ["embedded quotes", 'pre"two words"post', ["pretwo wordspost"]],
    ["unclosed quote", 'alpha "two words', ["alpha", "two words"]],
    ["unicode whitespace", "日本語\t🎉 café", ["日本語", "🎉", "café"]],
  ] as const)("%s", (_name, input, expected) => {
    expect(parseCommandArgs(input)).toEqual(expected);
  });
});

describe("substituteArgs", () => {
  test.each([
    ["all arguments", "Test: $ARGUMENTS", ["a", "b", "c"], "Test: a b c"],
    ["at alias", "Test: $@", ["a", "b", "c"], "Test: a b c"],
    ["single pass", "$ARGUMENTS", ["$1", "$ARGUMENTS"], "$1 $ARGUMENTS"],
    ["mixed placeholders", "$1 $2: $@", ["a", "b"], "a b: a b"],
    ["empty positional", "Test: $1", [], "Test: "],
    ["out of range", "$1 $2 $3 $4", ["a", "b"], "a b  "],
    ["zero positional", "$0", ["a"], ""],
    ["decimal suffix", "$1.5", ["a"], "a.5"],
    ["unicode", "$ARGUMENTS", ["日本語", "🎉", "café"], "日本語 🎉 café"],
    ["newlines and tabs", "$1 $2", ["line1\nline2", "tab\there"], "line1\nline2 tab\there"],
    ["adjacent", "$1$2", ["a", "b"], "ab"],
    ["unknown forms remain", "$A $$ $ $ARGS", ["a"], "$A $$ $ $ARGS"],
    ["case sensitive", "$arguments $Arguments $ARGUMENTS", ["a", "b"], "$arguments $Arguments a b"],
    ["positional default missing", "${2:-fallback}", ["a"], "fallback"],
    ["positional default empty", "${1:-fallback}", [""], "fallback"],
    ["positional default present", "${1:-fallback}", ["value"], "value"],
    ["all default empty", "${@:-fallback}", [], "fallback"],
    ["arguments default empty", "${ARGUMENTS:-fallback}", [], "fallback"],
    ["all default present", "${@:-fallback}", ["a", "b"], "a b"],
    ["default is not recursive", "${1:-$2}", [], "$2"],
    ["slice from index", "${@:2}", ["a", "b", "c", "d"], "b c d"],
    ["slice with length", "${@:2:2}", ["a", "b", "c", "d"], "b c"],
    ["slice out of range", "${@:99}", ["a", "b"], ""],
    ["zero-length slice", "${@:2:0}", ["a", "b", "c"], ""],
    ["oversized slice", "${@:2:99}", ["a", "b", "c"], "b c"],
    ["zero start means all", "${@:0}", ["a", "b", "c"], "a b c"],
    ["slice before at", "${@:2} vs $@", ["a", "b", "c"], "b c vs a b c"],
    ["slice is not recursive", "${@:1}", ["${@:2}", "test"], "${@:2} test"],
    [
      "combined forms",
      "Run $1 on ${@:2:2}, then $@",
      ["eslint", "a", "b", "c"],
      "Run eslint on a b, then eslint a b c",
    ],
    ["slice without spacing", "pre${@:2}post", ["a", "b", "c"], "preb cpost"],
  ] as const)("%s", (_name, template, args, expected) => {
    expect(substituteArgs(template, [...args])).toBe(expected);
  });
});
