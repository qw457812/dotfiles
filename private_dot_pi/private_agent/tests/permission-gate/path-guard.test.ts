import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import pathGuard from "../../extensions/permission-gate/path-guard.ts";

type Handler = (
  event: { toolName: string; input: { path?: string } },
  ctx: {
    cwd: string;
    hasUI: boolean;
    ui: { confirm: ReturnType<typeof vi.fn> };
    abort: ReturnType<typeof vi.fn>;
  },
) => Promise<{ block: boolean; reason: string } | undefined>;

function harness(approved = true, hasUI = true) {
  let handler: Handler | undefined;
  const emit = vi.fn();
  pathGuard({
    on: (_event: string, callback: Handler) => {
      handler = callback;
    },
    events: { emit },
  } as unknown as ExtensionAPI);
  const ctx = {
    cwd: "/repo",
    hasUI,
    ui: { confirm: vi.fn(async () => approved) },
    abort: vi.fn(),
  };
  return {
    ctx,
    emit,
    run: (path?: string, toolName = "bash") => {
      if (!handler) throw new Error("Path Guard handler not registered");
      return handler({ toolName, input: { path } }, ctx);
    },
  };
}

describe("Path Guard", () => {
  it("does not duplicate bash confirmation", async () => {
    const { run, ctx } = harness(false, true);
    expect(await run("sudo rm -rf /; echo DROP TABLE")).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });

  it.each(["write", "edit"])(
    "preserves protected-path confirmation and denial: %s",
    async (tool) => {
      const { run, ctx } = harness(false, true);
      expect(await run("/repo/.env", tool)).toEqual({
        block: true,
        reason: "Protected path: .env",
      });
      expect(ctx.ui.confirm).toHaveBeenCalledWith(
        "🛡️ Protected Path",
        "Allow write to /repo/.env?",
      );
      expect(ctx.abort).toHaveBeenCalledOnce();
    },
  );

  it.each(["write", "edit"])("blocks protected paths without UI: %s", async (tool) => {
    const { run, ctx } = harness(true, false);
    expect(await run("/repo/.env", tool)).toEqual({ block: true, reason: "Protected path: .env" });
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });
});

describe("Path Guard matching", () => {
  it.each(["/repo", getAgentDir()])("keeps the same protected paths in cwd=%s", async (cwd) => {
    const { run, ctx } = harness(true, false);
    ctx.cwd = cwd;
    for (const hit of [".env", ".git/", "node_modules/", "id_rsa", ".ssh/"])
      expect(await run(`/repo/${hit}file`, "write")).toEqual({
        block: true,
        reason: `Protected path: ${hit}`,
      });
    expect(await run("/repo/.pi/settings.json", "write")).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });

  it.each(["write", "edit"])("allows an approved protected %s path", async (tool) => {
    const { run, ctx, emit } = harness();
    expect(await run("/repo/.env", tool)).toBeUndefined();
    expect(ctx.ui.confirm).toHaveBeenCalledExactlyOnceWith(
      "🛡️ Protected Path",
      "Allow write to /repo/.env?",
    );
    expect(emit).toHaveBeenCalledExactlyOnceWith("my:notification", {
      title: "Pi Path Approval",
      body: "/repo/.env",
    });
    expect(ctx.abort).not.toHaveBeenCalled();
  });

  it("stays silent for read, unprotected and missing paths", async () => {
    const { run, ctx, emit } = harness();
    expect(await run("/repo/.env", "read")).toBeUndefined();
    for (const tool of ["write", "edit"]) {
      expect(await run("/repo/src/index.ts", tool)).toBeUndefined();
      expect(await run(undefined, tool)).toBeUndefined();
    }
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(emit).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });
});
