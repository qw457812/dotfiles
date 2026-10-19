import type { ExtensionContext, ToolExecutionEndEvent } from "@earendil-works/pi-coding-agent";
import { describe, expect, it } from "vitest";
import { createToolCounter } from "../../extensions/custom-footer/tool-counter.js";

function toolCounterCtx(entries: unknown[]) {
  return {
    sessionManager: { getEntries: () => entries },
  } as unknown as ExtensionContext;
}

function toolResult(toolName: string, isError = false, nestedCalls?: unknown) {
  return {
    type: "message",
    message: {
      role: "toolResult",
      toolName,
      isError,
      ...(nestedCalls === undefined ? {} : { nestedCalls }),
    },
  };
}

function plainTheme() {
  const fg = (_color: string, text: string) => text;
  return { fg };
}

describe("custom footer tool tally", () => {
  it("counts top-level tool results by name and error state", () => {
    const counter = createToolCounter();
    counter.onSessionStart(
      toolCounterCtx([
        { type: "model_change" },
        toolResult("bash"),
        toolResult("bash"),
        toolResult("bash", true),
        toolResult("read"),
        { type: "message", message: { role: "user" } },
        { type: "message", message: { role: "assistant" } },
      ]),
    );
    expect(counter.getToolTally(plainTheme())).toBe("bash 2 1 read 1");
  });

  it("counts nested calls, mapping ok to success and error/unfinished to error", () => {
    const counter = createToolCounter();
    counter.onSessionStart(
      toolCounterCtx([
        toolResult("codemode", false, {
          complete: true,
          calls: [
            { name: "read", status: "ok" },
            { name: "read", status: "ok" },
            { name: "bash", status: "error" },
            { name: "write", status: "unfinished" },
          ],
        }),
      ]),
    );
    expect(counter.getToolTally(plainTheme())).toBe("bash 1 codemode 1 read 2 write 1");
  });

  it("replaces prior counts instead of accumulating", () => {
    const counter = createToolCounter();
    const entries = [toolResult("bash"), toolResult("read")];
    counter.onSessionStart(toolCounterCtx(entries));
    counter.onSessionStart(toolCounterCtx(entries));
    expect(counter.getToolTally(plainTheme())).toBe("bash 1 read 1");
  });

  it("keeps counts made after hydrate", () => {
    const counter = createToolCounter();
    counter.onSessionStart(toolCounterCtx([toolResult("bash")]));
    counter.onToolExecutionEnd({ toolName: "read", isError: false } as ToolExecutionEndEvent);
    counter.onToolExecutionEnd({ toolName: "read", isError: true } as ToolExecutionEndEvent);
    expect(counter.getToolTally(plainTheme())).toBe("bash 1 read 1 1");
  });

  it("yields no tally for an empty session", () => {
    const counter = createToolCounter();
    counter.onSessionStart(toolCounterCtx([]));
    expect(counter.getToolTally(plainTheme())).toBeNull();
  });
});
