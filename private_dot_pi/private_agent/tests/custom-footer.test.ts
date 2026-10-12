import type { ExtensionContext, ToolExecutionEndEvent } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import { createToolCounter } from "../extensions/custom-footer/tool-counter.js";
import { createSessionStatsGetter } from "../extensions/custom-footer/session-stats.js";

function usage(input = 10, cacheRead = 30) {
  return { input, output: 5, cacheRead, cacheWrite: 0, cost: { total: 0.01 } };
}

function assistant(model = "physical", stopReason = "stop", tokens = usage()) {
  return {
    role: "assistant",
    provider: "test",
    model,
    thinkingLevel: "high",
    stopReason,
    usage: tokens,
  };
}

function fixture() {
  const state = {
    sessionId: "session-1",
    leafId: "leaf-1" as string | null,
    model: { id: "selected", api: "openai-responses", provider: "selected-provider" },
    entries: [{ type: "message", message: assistant() }] as unknown[],
    messages: [assistant()],
    contextUsage: { tokens: 40 as number | null, contextWindow: 1000, percent: 4 as number | null },
  };
  const getEntries = vi.fn(() => state.entries);
  const getContextUsage = vi.fn(() => state.contextUsage);
  const buildSessionProjection = vi.fn(() => ({ messages: state.messages }));
  const ctx = {
    get model() {
      return state.model;
    },
    sessionManager: {
      getSessionId: () => state.sessionId,
      getLeafId: () => state.leafId,
      getEntries,
      buildSessionProjection,
    },
    modelRegistry: {
      find: vi.fn((_provider: string, id: string) => ({ id, api: "openai-responses" })),
    },
    getContextUsage,
  } as unknown as ExtensionContext;
  return {
    state,
    getEntries,
    getContextUsage,
    buildSessionProjection,
    read: createSessionStatsGetter(ctx),
  };
}

describe("custom footer session stats", () => {
  it("reuses statistics across frames and invalidates on session, leaf, model or revision changes", () => {
    const f = fixture();
    const first = f.read(0);
    expect(f.read(0)).toBe(first);
    expect(f.getEntries).toHaveBeenCalledTimes(1);
    expect(f.getContextUsage).toHaveBeenCalledTimes(1);

    f.state.leafId = "leaf-2";
    expect(f.read(0)).not.toBe(first);
    f.state.sessionId = "session-2";
    f.read(0);
    f.state.model = { ...f.state.model };
    f.read(0);
    f.read(1);
    expect(f.getEntries).toHaveBeenCalledTimes(5);
    expect(f.getContextUsage).toHaveBeenCalledTimes(5);
  });

  it("includes all usage sources and retains the latest assistant cache-hit rate", () => {
    const f = fixture();
    f.state.entries = [
      { type: "message", message: assistant() },
      { type: "usage", usage: usage() },
      { type: "message", message: { role: "toolResult", usage: usage() } },
      { type: "message", message: { role: "toolResult" } },
      { type: "compaction", usage: usage() },
      { type: "branch_summary", usage: usage() },
      { type: "compaction" },
    ];
    expect(f.read(0)).toMatchObject({
      input: 50,
      output: 25,
      cacheRead: 150,
      cacheWrite: 0,
      cost: 0.05,
      latestCacheHitRate: 75,
    });
    f.state.entries.push({ type: "message", message: assistant("physical", "stop", usage(0, 0)) });
    f.state.leafId = "next";
    expect(f.read(0).latestCacheHitRate).toBeUndefined();
  });

  it("refreshes unknown context usage after compaction", () => {
    const f = fixture();
    f.read(0);
    f.state.contextUsage = { tokens: null, percent: null, contextWindow: 1000 };
    f.state.leafId = "compacted";
    expect(f.read(0).contextUsage?.percent).toBeNull();
  });

  it("shows only the latest successful projected response under a virtual selection", () => {
    const f = fixture();
    expect(f.read(0).routed).toBeUndefined();
    expect(f.buildSessionProjection).not.toHaveBeenCalled();

    f.state.model = { id: "auto", api: "pi-virtual", provider: "router" };
    f.state.entries.push({ type: "message", message: assistant("abandoned-branch") });
    f.state.messages = [
      assistant("branch-model"),
      assistant("failed", "error"),
      assistant("cancelled", "aborted"),
    ];
    expect(f.read(0).routed).toEqual({
      provider: "test",
      modelId: "branch-model",
      thinkingLevel: "high",
    });

    f.state.messages = [{ ...assistant("other-branch"), provider: "other-provider" }];
    f.state.leafId = "other-leaf";
    expect(f.read(0).routed?.modelId).toBe("other-branch");
    expect(f.read(0).routed?.provider).toBe("other-provider");

    f.state.messages = [];
    f.state.leafId = null;
    expect(f.read(0).routed).toBeUndefined();
  });
});

function toolCounterCtx(entries: unknown[]) {
  return {
    sessionManager: { getEntries: () => entries },
  } as unknown as ExtensionContext;
}

function toolResult(toolName: string, isError = false, nestedCalls?: unknown) {
  return {
    type: "message",
    message: { role: "toolResult", toolName, isError, ...(nestedCalls === undefined ? {} : { nestedCalls }) },
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
