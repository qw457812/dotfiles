import { expect, it } from "vitest";
import { lastAssistantText } from "../extensions/last-message.js";

type Message = Parameters<typeof lastAssistantText>[0][number];
type Part = { type: "text"; text: string } | { type: "toolCall"; name: string };

function message(role: string, ...parts: Part[]): Message {
  return { role, content: parts } as unknown as Message;
}

it("returns the last assistant text", () => {
  expect(
    lastAssistantText([
      message("user", { type: "text", text: "hi" }),
      message("assistant", { type: "text", text: "first" }),
      message("assistant", { type: "text", text: "second" }),
    ]),
  ).toBe("second");
});

it("skips the user message after it", () => {
  expect(
    lastAssistantText([
      message("assistant", { type: "text", text: "answer" }),
      message("user", { type: "text", text: "next question" }),
    ]),
  ).toBe("answer");
});

it("concatenates text parts and ignores tool calls", () => {
  expect(
    lastAssistantText([
      message(
        "assistant",
        { type: "text", text: "part one " },
        { type: "toolCall", name: "bash" },
        { type: "text", text: "part two" },
      ),
    ]),
  ).toBe("part one part two");
});

it("skips tool-only turns and falls back to the last reply with text", () => {
  expect(
    lastAssistantText([
      message("assistant", { type: "text", text: "answer" }),
      message("assistant", { type: "toolCall", name: "read" }),
    ]),
  ).toBe("answer");
});

it("returns undefined when no assistant message has text", () => {
  expect(lastAssistantText([])).toBeUndefined();
  expect(lastAssistantText([message("user", { type: "text", text: "hi" })])).toBeUndefined();
  expect(lastAssistantText([message("assistant", { type: "text", text: "   " })])).toBeUndefined();
});
