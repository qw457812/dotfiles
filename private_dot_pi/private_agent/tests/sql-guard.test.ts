import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import sqlGuard from "../extensions/sql-guard";

type Handler = (
  event: { toolName: string; input: Record<string, unknown>; parentToolCallId?: string },
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
    run: (toolName: string, input: Record<string, unknown>) => {
      if (!handler) throw new Error("SQL Guard handler not registered");
      return handler({ toolName, input }, ctx);
    },
  };
}

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
