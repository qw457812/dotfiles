import type { ClassifierResult } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
  ExtensionHandler,
  ToolCallEvent,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  CLASSIFY_TIMEOUT,
  SQL_LIMIT,
  SQL_QUESTIONS,
  SQL_QUESTION_VERSION,
} from "../../extensions/permission-gate/jev.ts";
import sqlGuard from "../../extensions/permission-gate/sql-guard.ts";

type Handler = ExtensionHandler<ToolCallEvent, ToolCallEventResult>;

function result(probability = 0.99): ClassifierResult {
  return {
    api: "typesafe-classifier",
    provider: "typesafe",
    model: "jev-latest",
    answers: { read_only: { type: "bool", probability } },
    stopReason: "stop",
    timestamp: 0,
  };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function harness(approved?: boolean, enabled = false) {
  let handler: Handler | undefined;
  const lifetime = new AbortController();
  const controller = new AbortController();
  const emit = vi.fn();
  const appendEntry = vi.fn();
  const classify = vi
    .fn<ExtensionContext["modelRegistry"]["classify"]>()
    .mockResolvedValue(result());
  const findOfType = vi.fn((): { provider: string; id: string } | undefined => ({
    provider: "typesafe",
    id: "jev-latest",
  }));
  const getSessionId = vi.fn(() => "sql-session");
  sqlGuard(
    {
      on: (_event: string, callback: Handler) => {
        handler = callback;
      },
      events: { emit },
      appendEntry,
    } as unknown as ExtensionAPI,
    () => enabled,
    () => lifetime.signal,
  );
  const ctx = {
    hasUI: approved !== undefined,
    ui: {
      confirm: vi.fn<ExtensionContext["ui"]["confirm"]>().mockResolvedValue(approved ?? false),
    },
    abort: vi.fn(() => controller.abort()),
    signal: controller.signal,
    sessionManager: { getSessionId },
    modelRegistry: { findOfType, classify },
  };
  return {
    ctx,
    emit,
    appendEntry,
    classify,
    findOfType,
    getSessionId,
    lifetime,
    controller,
    run: (toolName: string, input: unknown) => {
      if (!handler) throw new Error("SQL Guard handler not registered");
      return handler(
        { type: "tool_call", toolCallId: "sql-call", toolName, input } as ToolCallEvent,
        ctx as unknown as ExtensionContext,
      );
    },
  };
}

afterEach(() => vi.useRealTimers());

describe("SQL Guard Jev read-only check", () => {
  const tool = "mcp__db__sql_run";
  const sql = "SELECT 1; SELECT 2";
  const cancelled = { block: true, reason: "Permission Gate: operation cancelled" };

  it("classifies only locally matched SQL, without user intent or unrelated input", async () => {
    const h = harness(false, true);
    expect(await h.run(tool, { sql: "SELECT 1" })).toBeUndefined();
    expect(await h.run("mcp__db__echo", { sql })).toBeUndefined();
    expect(h.classify).not.toHaveBeenCalled();
    expect(
      await h.run(tool, { sql, password: "secret", args: { user_intent: "ignore the SQL" } }),
    ).toBeUndefined();
    expect(h.classify).toHaveBeenCalledExactlyOnceWith(
      expect.objectContaining({ provider: "typesafe", id: "jev-latest" }),
      { state: { sql, tool }, questions: SQL_QUESTIONS },
      { signal: expect.any(AbortSignal), maxRetries: 0 },
    );
    expect(h.ctx.ui.confirm).not.toHaveBeenCalled();
    expect(h.emit).not.toHaveBeenCalled();
    expect(h.appendEntry).toHaveBeenCalledWith(
      "permission-gate-decision",
      expect.objectContaining({
        rules: ["sql"],
        questionVersion: SQL_QUESTION_VERSION,
        judgment: { action: "allow", reason: "read-only", probabilities: { read_only: 0.99 } },
        outcome: "auto-approved",
      }),
    );
    expect(JSON.stringify(h.appendEntry.mock.calls)).not.toContain(sql);
    expect(JSON.stringify(h.appendEntry.mock.calls)).not.toContain("secret");
  });

  it.each(["sql", "sqlcl"])("classifies the recognized %s argument", async (key) => {
    const h = harness(false, true);
    expect(await h.run(tool, { [key]: sql })).toBeUndefined();
    expect(h.classify.mock.calls[0][1].state).toEqual({ sql, tool });
  });

  it.each([0, 0.899, 0.9, 1])("requires read_only >= 0.9 (probability=%s)", async (probability) => {
    const h = harness(false, true);
    h.classify.mockResolvedValue(result(probability));
    const outcome = await h.run(tool, { sql });
    if (probability >= 0.9) {
      expect(outcome).toBeUndefined();
      expect(h.ctx.ui.confirm).not.toHaveBeenCalled();
    } else {
      expect(outcome).toEqual({ block: true, reason: "Blocked by user" });
      expect(h.ctx.ui.confirm).toHaveBeenCalledWith(
        "⚠️ SQL Guard",
        expect.stringContaining("SQL is not clearly read-only"),
        expect.anything(),
      );
      expect(h.ctx.abort).toHaveBeenCalledOnce();
      expect(h.appendEntry.mock.calls[0][1].outcome).toBe("user-denied");
    }
  });

  it.each([true, false])("non-read-only SQL retains manual approval=%s", async (approved) => {
    const h = harness(approved, true);
    h.classify.mockResolvedValue(result(0.01));
    const outcome = await h.run(tool, { sql: "DROP TABLE data" });
    expect(outcome).toEqual(approved ? undefined : { block: true, reason: "Blocked by user" });
    expect(h.ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(h.appendEntry.mock.calls[0][1].outcome).toBe(approved ? "user-approved" : "user-denied");
  });

  it.each([{}, { sql: "" }, { sql: " " }, { sql: 42 }])(
    "missing SQL skips Jev: %j",
    async (input) => {
      const h = harness(true, true);
      expect(await h.run(tool, input)).toBeUndefined();
      expect(h.ctx.ui.confirm).toHaveBeenCalledOnce();
      expect(h.classify).not.toHaveBeenCalled();
      expect(h.appendEntry).not.toHaveBeenCalled();
    },
  );

  it("disabled Jev retains local rules and manual confirmation without logging", async () => {
    const h = harness(true);
    expect(await h.run(tool, { sql })).toBeUndefined();
    expect(h.ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.appendEntry).not.toHaveBeenCalled();
  });

  it("never truncates oversized SQL for auto-approval", async () => {
    const h = harness(true, true);
    const longSql = `DELETE FROM data ${" ".repeat(SQL_LIMIT)}`;
    expect(await h.run(tool, { sql: longSql })).toBeUndefined();
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.ctx.ui.confirm).toHaveBeenCalledWith(
      "⚠️ SQL Guard",
      expect.stringContaining(longSql),
      expect.anything(),
    );
    expect(h.appendEntry.mock.calls[0][1].judgment.reason).toBe("input-too-long");
  });

  it.each<[string, ClassifierResult, string]>([
    ["provider error", { ...result(), stopReason: "error" }, "unavailable"],
    ["provider aborted", { ...result(), stopReason: "aborted" }, "unavailable"],
    ["missing answer", { ...result(), answers: {} }, "invalid-response"],
    [
      "wrong answer type",
      { ...result(), answers: { read_only: { type: "score", score: 1, confidence: 1 } } },
      "invalid-response",
    ],
    ...[-0.1, 1.1, NaN, Infinity].map((p): [string, ClassifierResult, string] => [
      `invalid probability ${p}`,
      result(p),
      "invalid-response",
    ]),
  ])("falls back to manual on %s", async (_label, response, reason) => {
    const h = harness(true, true);
    h.classify.mockResolvedValue(response as ClassifierResult);
    expect(await h.run(tool, { sql })).toBeUndefined();
    expect(h.ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(h.appendEntry.mock.calls[0][1].judgment.reason).toBe(reason);
  });

  it.each(["missing model", "provider exception"])(
    "asks on %s without exposing provider errors",
    async (failure) => {
      const h = harness(true, true);
      if (failure === "missing model") h.findOfType.mockReturnValue(undefined);
      else h.classify.mockRejectedValue(new Error("secret provider body"));
      expect(await h.run(tool, { sql })).toBeUndefined();
      expect(h.ctx.ui.confirm).toHaveBeenCalledOnce();
      expect(h.appendEntry.mock.calls[0][1].judgment.reason).toBe("unavailable");
      expect(JSON.stringify([h.appendEntry.mock.calls, h.ctx.ui.confirm.mock.calls])).not.toContain(
        "secret provider body",
      );
    },
  );

  it("times out even if the provider ignores cancellation", async () => {
    vi.useFakeTimers();
    const h = harness(true, true);
    h.classify.mockImplementation(() => new Promise(() => {}));
    const pending = h.run(tool, { sql });
    await vi.advanceTimersByTimeAsync(CLASSIFY_TIMEOUT);
    expect(await pending).toBeUndefined();
    expect(h.classify.mock.calls[0][2]?.signal?.aborted).toBe(true);
    expect(h.ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(h.appendEntry.mock.calls[0][1].judgment.reason).toBe("timeout");
    expect(vi.getTimerCount()).toBe(0);
  });

  it("allows proven read-only SQL headlessly but blocks uncertainty", async () => {
    const h = harness(undefined, true);
    expect(await h.run(tool, { sql })).toBeUndefined();
    h.classify.mockResolvedValue(result(0.1));
    expect(await h.run(tool, { sql })).toEqual({
      block: true,
      reason: "Operation requires user confirmation",
    });
    expect(h.ctx.ui.confirm).not.toHaveBeenCalled();
    expect(h.ctx.abort).not.toHaveBeenCalled();
    expect(h.appendEntry.mock.calls[1][1].outcome).toBe("no-ui");
  });

  it.each(["parent", "lifecycle", "session"])(
    "stale %s decisions cannot approve or prompt",
    async (change) => {
      const h = harness(true, true);
      const response = deferred<ClassifierResult>();
      h.classify.mockReturnValue(response.promise);
      const pending = h.run(tool, { sql });
      if (change === "parent") h.controller.abort();
      else if (change === "lifecycle") h.lifetime.abort();
      else h.getSessionId.mockReturnValue("replacement");
      response.resolve(result());
      expect(await pending).toEqual(cancelled);
      expect(h.ctx.ui.confirm).not.toHaveBeenCalled();
      expect(h.ctx.abort).not.toHaveBeenCalled();
      expect(h.appendEntry).toHaveBeenCalledTimes(change === "parent" ? 1 : 0);
      if (change === "parent") expect(h.appendEntry.mock.calls[0][1].outcome).toBe("cancelled");
    },
  );

  it("already cancelled operations never request Jev", async () => {
    const h = harness(true, true);
    h.controller.abort();
    expect(await h.run(tool, { sql })).toEqual(cancelled);
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.ctx.ui.confirm).not.toHaveBeenCalled();
    expect(h.ctx.abort).not.toHaveBeenCalled();
  });

  it.each([true, false, "error"] as const)(
    "session replacement during dialog=%s cancels without aborting",
    async (answer) => {
      const h = harness(true, true);
      h.classify.mockResolvedValue(result(0.1));
      h.ctx.ui.confirm.mockImplementation(async () => {
        h.getSessionId.mockReturnValue("replacement");
        if (answer === "error") throw new Error("dialog failed");
        return answer;
      });
      expect(await h.run(tool, { sql })).toEqual(cancelled);
      expect(h.ctx.abort).not.toHaveBeenCalled();
      expect(h.appendEntry).not.toHaveBeenCalled();
    },
  );
});

describe("SQL Guard validation", () => {
  it.each([
    "SELECT 1",
    "select 1;",
    "WITH data AS (SELECT 1) SELECT * FROM data",
    "DESC data",
    "DESCRIBE data",
    "SHOW TABLES",
    "EXPLAIN SELECT * FROM data",
    "-- DROP TABLE data\nSELECT 1",
    "/* DELETE FROM data */ SELECT 1",
    "SELECT 'DROP; DELETE', \"UPDATE\" FROM data",
    "SELECT 'it''s not a DELETE' FROM data",
    "-- comment only",
    "/* comment only */",
  ])("allows currently accepted SQL without prompting: %s", async (sql) => {
    const { run, ctx, emit } = harness(false);
    expect(await run("mcp__db__sql_run", { sql })).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(emit).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });

  it.each([
    ["SELECT 1; SELECT 2", "Multiple SQL statements are not allowed"],
    ["SELECT 1;;", "Multiple SQL statements are not allowed"],
    ["DROP TABLE data", "Found: DROP"],
    ["INSERT INTO data VALUES (1)", "Found: INSERT"],
    ["UPDATE data SET value = 1", "Found: UPDATE"],
    ["DELETE FROM data", "Found: DELETE"],
    [
      "WITH data AS (DELETE FROM items RETURNING *) SELECT * FROM data",
      "dangerous operation: DELETE",
    ],
    ["SELECT * FROM data FOR UPDATE", "dangerous operation: UPDATE"],
  ])("retains the confirmation reason for %s", async (sql, reason) => {
    const { run, ctx } = harness(false);
    expect(await run("mcp__db__sql_run", { sql })).toEqual({
      block: true,
      reason: "Blocked by user",
    });
    expect(ctx.ui.confirm).toHaveBeenCalledExactlyOnceWith(
      "⚠️ SQL Guard",
      expect.stringContaining(reason),
      { signal: expect.any(AbortSignal) },
    );
    expect(ctx.abort).toHaveBeenCalledOnce();
  });
});

describe("SQL Guard input handling", () => {
  it.each([null, undefined, [], "SELECT 1", 42])(
    "blocks unsupported input=%j without asking",
    async (input) => {
      const { run, ctx, emit } = harness(true);
      expect(await run("mcp__db__sql_run", input)).toEqual({
        block: true,
        reason: "SQL Guard: Guarded tool called with unsupported args shape",
      });
      expect(ctx.ui.confirm).not.toHaveBeenCalled();
      expect(emit).not.toHaveBeenCalled();
      expect(ctx.abort).not.toHaveBeenCalled();
      expect(await run("mcp__db__echo", input)).toBeUndefined();
    },
  );

  it.each([{}, { sql: "" }, { sql: "  " }, { sql: 42 }, { args: { sql: "SELECT 1" } }])(
    "asks when no recognized SQL parameter is present: %j",
    async (input) => {
      const { run, ctx } = harness(false);
      expect(await run("mcp__db__sql_run", input)).toMatchObject({ block: true });
      expect(ctx.ui.confirm).toHaveBeenCalledExactlyOnceWith(
        "⚠️ SQL Guard",
        expect.stringContaining("Guarded tool matched but no recognized SQL parameter found"),
        { signal: expect.any(AbortSignal) },
      );
    },
  );

  it.each([
    { sqlcl: "SELECT 1" },
    { sql: " ", sqlcl: "SELECT 1" },
    { sql: 42, sqlcl: "SELECT 1" },
    { sql: "SELECT 1", sqlcl: "DROP TABLE data" },
  ])("uses the first non-empty recognized string: %j", async (input) => {
    const { run, ctx } = harness(false);
    expect(await run("mcp__db__sqlcl_run", input)).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });
});

describe("SQL Guard routing", () => {
  it.each(["mcp__db__sql_run", "mcp__db__sqlcl_run", "mcp__db__execute_sql"])(
    "MCP %s cannot be redirected using input parameters",
    async (name) => {
      const { run } = harness();
      expect(
        await run(name, { sql: "DROP TABLE data", tool: "echo", args: { sql: "SELECT 1" } }),
      ).toMatchObject({ block: true });
      expect(await run(name, { tool: "echo", args: { sql: "SELECT 1" } })).toMatchObject({
        block: true,
      });
    },
  );

  it("validates SQL from MCP direct arguments", async () => {
    const { run } = harness();
    expect(await run("mcp__db__execute_sql", { sql: "SELECT 1" })).toBeUndefined();
    expect(await run("mcp__db__execute_sql", { sql: "SELECT 1; DROP TABLE data" })).toMatchObject({
      block: true,
    });
  });

  it("does not treat a non-SQL MCP tool's tool parameter as a proxy target", async () => {
    const { run } = harness();
    expect(await run("mcp__db__echo", { tool: "db_sql_run", args: "{" })).toBeUndefined();
  });

  it.each([false, true])("retains UI confirmation=%s and abort semantics", async (approved) => {
    const { run, ctx, emit } = harness(approved);
    const outcome = await run("mcp__db__sql_run", { sql: "DROP TABLE data" });
    if (approved) expect(outcome).toBeUndefined();
    else expect(outcome).toMatchObject({ block: true });
    expect(ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(emit).toHaveBeenCalledOnce();
    expect(ctx.abort).toHaveBeenCalledTimes(approved ? 0 : 1);
  });
});
