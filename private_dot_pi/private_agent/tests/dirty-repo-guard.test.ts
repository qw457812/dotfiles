import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import dirtyRepoGuard from "../extensions/dirty-repo-guard.ts";

function harness(stdout = "", hasUI = true) {
  const ctx = { hasUI, ui: { notify: vi.fn() } };
  let start: ((event: unknown, context: typeof ctx) => Promise<void>) | undefined;
  const on = vi.fn((event: string, handler: NonNullable<typeof start>) => {
    if (event === "session_start") start = handler;
  });
  const exec = vi.fn(async () => ({ stdout }));
  const registerCommand = vi.fn();
  dirtyRepoGuard({ on, exec, registerCommand } as unknown as ExtensionAPI);
  return {
    ctx,
    on,
    exec,
    registerCommand,
    start: async () => {
      if (!start) throw new Error("Session start handler not registered");
      await start({}, ctx);
    },
  };
}

describe("Dirty Repo Guard", () => {
  it("registers only the session reminder, not bash checks or commands", () => {
    const { on, registerCommand } = harness();
    expect(on).toHaveBeenCalledOnce();
    expect(on).toHaveBeenCalledWith("session_start", expect.any(Function));
    expect(registerCommand).not.toHaveBeenCalled();
  });

  it("warns with the number of uncommitted changes", async () => {
    const { start, exec, ctx } = harness(" M file\n?? other\n");
    await start();
    expect(exec).toHaveBeenCalledWith("git", ["status", "--porcelain"]);
    expect(ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
      "⚠️ Dirty repo: 2 uncommitted change(s)",
      "warning",
    );
  });

  it.each([
    ["", true],
    ["  \n", true],
    [" M file\n", false],
  ] as const)("stays silent for stdout=%j and hasUI=%s", async (stdout, hasUI) => {
    const { start, ctx } = harness(stdout, hasUI);
    await start();
    expect(ctx.ui.notify).not.toHaveBeenCalled();
  });

  it("ignores Git errors outside repositories", async () => {
    const { start, exec, ctx } = harness();
    exec.mockRejectedValueOnce(new Error("not a git repository"));
    await expect(start()).resolves.toBeUndefined();
    expect(ctx.ui.notify).not.toHaveBeenCalled();
  });
});
