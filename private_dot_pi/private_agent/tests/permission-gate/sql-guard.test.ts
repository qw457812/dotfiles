import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import sqlGuard from "../../extensions/permission-gate/sql-guard.ts";

type Handler = (
  event: { toolName: string; input: unknown; parentToolCallId?: string },
  ctx: {
    hasUI: boolean;
    ui: { confirm: ReturnType<typeof vi.fn> };
    abort: ReturnType<typeof vi.fn>;
  },
) => Promise<{ block: boolean; reason: string } | undefined>;

function harness(approved?: boolean) {
  let handler: Handler | undefined;
  const emit = vi.fn();
  sqlGuard({
    on: (_event: string, callback: Handler) => {
      handler = callback;
    },
    events: { emit },
  } as unknown as ExtensionAPI);
  const ctx = {
    hasUI: approved !== undefined,
    ui: { confirm: vi.fn(async () => approved ?? false) },
    abort: vi.fn(),
  };
  return {
    ctx,
    emit,
    run: (toolName: string, input: unknown) => {
      if (!handler) throw new Error("SQL Guard handler not registered");
      return handler({ toolName, input }, ctx);
    },
  };
}

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
