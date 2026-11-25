import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import permissionGate from "../../extensions/permission-gate/index.ts";
import dirtyRepoGuard from "../../extensions/dirty-repo-guard.ts";
import { initializeBashParser } from "../../lib/bash-parser.ts";

type Handler = (
  event: { toolName: string; input: { command?: string; path?: string } },
  ctx: {
    cwd: string;
    hasUI: boolean;
    ui: { confirm: ReturnType<typeof vi.fn>; notify: ReturnType<typeof vi.fn> };
    abort: ReturnType<typeof vi.fn>;
    sessionManager: { getSessionId: () => string; getBranch: () => [] };
  },
) => Promise<{ block: boolean; reason: string } | undefined>;

type GateCommand = {
  handler: (args: string, ctx: Parameters<Handler>[1]) => Promise<void>;
  getArgumentCompletions: (prefix: string) => { value: string; label: string }[] | null;
};

function harness(approved = true, hasUI = true, extension = permissionGate) {
  const handlers: Handler[] = [];
  let gateCommand: GateCommand | undefined;
  const emit = vi.fn();
  extension({
    on: (event: string, callback: Handler) => {
      if (event === "tool_call") handlers.push(callback);
    },
    events: { emit },
    registerCommand: (name: string, command: GateCommand) => {
      if (name === "gate") gateCommand = command;
    },
  } as unknown as ExtensionAPI);
  const ctx = {
    cwd: "/repo",
    hasUI,
    ui: { confirm: vi.fn(async (): Promise<boolean> => approved), notify: vi.fn() },
    abort: vi.fn(),
    sessionManager: { getSessionId: () => "test", getBranch: (): [] => [] },
  };
  // Existing cases exercise local matching and manual confirmation independently of Jev.
  void gateCommand?.handler("jev off", ctx);
  ctx.ui.notify.mockClear();
  return {
    ctx,
    emit,
    gateCommand,
    gate: (args: string) => {
      if (!gateCommand) throw new Error("Gate command not registered");
      return gateCommand.handler(args, ctx);
    },
    run: async (command: string, toolName = "bash") => {
      if (!handlers.length) throw new Error("Handler not registered");
      const event = { toolName, input: { command, path: command } };
      for (const handler of handlers) {
        const result = await handler(event, ctx);
        if (result?.block) return result;
      }
    },
  };
}

const NON_GIT_CASES = [
  "rm -rf dir",
  "rm -rf /tmp",
  'rm -rf "$DIR"',
  "chmod -R 777 dir",
  "chown -R user dir",
  "chgrp -R group dir",
  "sudo true",
  "dd if=input of=output",
  "mkfs.ext4 /dev/sda",
  "echo ok >/dev/sda",
  "git status >/dev/sda",
  'echo "unterminated',
];

const GIT_APPROVAL_CASES = [
  // guarded git subcommands
  "git merge",
  "git merge main",
  'git merge "unterminated',
  "git merge; echo done",
  "git merge&&echo done",
  "git merge|less",
  "(git merge)",
  "git -C '/repo path' merge main",
  "git merge-base HEAD main; git merge main",
  "git cherry-pick abc123",
  "git --no-pager merge main",
  "git -c user.name=test merge main",
  "git -C /repo -c user.name=test --no-pager merge main",
  "git -C/repo -cuser.name=test merge main",
  "git --git-dir=/repo/.git --work-tree /repo merge main",
  "git --config-env=user.name=GIT_NAME merge main",
  "git --git-dir /repo/.git --work-tree=/repo merge main",
  'git -C "$REPO" merge main',
  "git -- merge main",
  "git status || git merge main",
  "git merge main > /tmp/result",
  'echo "$(git merge main)"',
  "cat <(git merge main)",
  "cat <<EOF\n$(git merge main)\nEOF",
  "if true; then git merge main; fi",
  "/usr/bin/git merge main",
  "'git' 'merge' main",
  'git m"er"ge main',
  "g\\it mer\\ge main",
];

const GIT_CLEAR_CASES = [
  "git",
  'git "$ACTION" main',
  "git --unknown-option merge main",
  "git --unknown-subcommand",
  "git custom-alias",
  "git -C",
  "git --",
  "git merge-base --is-ancestor d60934e 6fd0ac75",
  'cd /repo && git log --oneline -1 d60934e; git merge-base --is-ancestor d60934e 6fd0ac75 && echo "IN INSTALLED" || echo "NOT in installed (target-only)"; git merge-base --is-ancestor d60934e 0126bc5a && echo "IN TARGET"',
  "git cherry-pick-helper",
  'echo "git merge"',
  "printf '%s' 'git commit'",
  "# git merge\ngit status",
  "cat <<'EOF'\ngit merge\nEOF",
  "git --no-pager merge-base HEAD main",
  "git -c note='git merge' status",
  'git --version; echo "git merge"',
  "git --help merge",
  'echo "literal $text git merge"',
];

describe("Permission Gate", () => {
  it.each(NON_GIT_CASES)("does not prompt or abort for unmatched commands: %s", async (command) => {
    const { run, ctx, emit } = harness(false);
    expect(await run(command)).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.ui.notify).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
    expect(emit).not.toHaveBeenCalled();
  });

  it.each([true, false])(
    "allows parser exceptions and warns only with UI (hasUI=%s)",
    async (hasUI) => {
      const parser = await initializeBashParser();
      const parse = vi.spyOn(parser, "parse").mockImplementation(() => {
        throw new Error("parser failed");
      });
      try {
        const { run, ctx, emit } = harness(false, hasUI);
        expect(await run("git reset --hard")).toBeUndefined();
        expect(ctx.ui.confirm).not.toHaveBeenCalled();
        expect(ctx.abort).not.toHaveBeenCalled();
        expect(emit).not.toHaveBeenCalled();
        if (hasUI) {
          expect(ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
            "Permission Gate: command checks skipped (parser failure)",
            "warning",
          );
        } else {
          expect(ctx.ui.notify).not.toHaveBeenCalled();
        }
      } finally {
        parse.mockRestore();
      }
    },
  );

  it("allows a missing parse tree and warns instead of confirming", async () => {
    const parser = await initializeBashParser();
    const parse = vi.spyOn(parser, "parse").mockReturnValue(null);
    try {
      const { run, ctx } = harness();
      expect(await run("git push")).toBeUndefined();
      expect(ctx.ui.confirm).not.toHaveBeenCalled();
      expect(ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
        "Permission Gate: command checks skipped (parser failure)",
        "warning",
      );
    } finally {
      parse.mockRestore();
    }
  });

  it.each(["write", "edit", "read"])("ignores non-bash tools: %s", async (tool) => {
    const { run, ctx } = harness();
    expect(await run("git reset --hard", tool)).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });
});

describe("Permission Gate Git rules", () => {
  it.each(GIT_APPROVAL_CASES)("asks for approval: %s", async (command) => {
    const { run, ctx } = harness();
    expect(await run(command)).toBeUndefined();
    expect(ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(ctx.ui.confirm).toHaveBeenCalledWith(
      "🔐 Allow this command?",
      expect.stringContaining(`\n\n${command}`),
      { signal: expect.any(AbortSignal) },
    );
  });

  it.each(GIT_CLEAR_CASES)("stays silent: %s", async (command) => {
    const { run, ctx } = harness();
    expect(await run(command)).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });

  it.each(GIT_CLEAR_CASES)("allows unmatched/unresolved Git without UI: %s", async (command) => {
    const { run, ctx } = harness(true, false);
    expect(await run(command)).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });

  it.each(GIT_APPROVAL_CASES)("blocks without UI: %s", async (command) => {
    const { run, ctx } = harness(true, false);
    expect(await run(command)).toEqual({
      block: true,
      reason: "Operation requires user confirmation",
    });
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });

  it("blocks and aborts when the user declines", async () => {
    const { run, ctx } = harness(false);
    expect(await run("git merge main")).toEqual({ block: true, reason: "Blocked by user" });
    expect(ctx.abort).toHaveBeenCalledOnce();
  });
});

describe("Permission Gate integration and Git toggle", () => {
  it.each(["git reset --hard; rm -rf dir", "git commit -m update && git push"])(
    "parses and confirms once with both extensions loaded: %s",
    async (command) => {
      const parser = await initializeBashParser();
      const parse = vi.spyOn(parser, "parse");
      try {
        const { run, ctx, emit } = harness(true, true, (pi) => {
          permissionGate(pi);
          dirtyRepoGuard(pi);
        });
        expect(await run(command)).toBeUndefined();
        expect(parse).toHaveBeenCalledOnce();
        expect(ctx.ui.confirm).toHaveBeenCalledExactlyOnceWith(
          "🔐 Allow this command?",
          expect.stringContaining(`\n\n${command}`),
          { signal: expect.any(AbortSignal) },
        );
        expect(emit).toHaveBeenCalledOnce();
      } finally {
        parse.mockRestore();
      }
    },
  );

  it.each([
    "add",
    "commit",
    "push",
    "pull",
    "merge",
    "rebase",
    "reset",
    "checkout",
    "switch",
    "stash",
    "cherry-pick",
    "revert",
    "restore",
    "clean",
  ])("guards Git subcommand %s by default", async (subcommand) => {
    const { run, ctx } = harness();
    await run(`git ${subcommand}`);
    expect(ctx.ui.confirm).toHaveBeenCalledOnce();
  });

  it("disables only recognized Git rules and re-enables them", async () => {
    const { run, ctx, gate } = harness();
    await gate("git  OFF ");
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Git approval: OFF", "info");
    await run("git reset --hard; git push");
    await run('git "$ACTION"');
    await run("git --unknown-option merge");
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    await gate("git on");
    await run("git reset --hard");
    expect(ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Git approval: ON", "info");
  });

  it("does not confirm syntax errors alone when Git rules are off", async () => {
    const { run, ctx, gate } = harness(true, false);
    await gate("git off");
    expect(await run('git merge "unterminated')).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });

  it("reports status and rejects invalid gate arguments without changing state", async () => {
    const { run, ctx, gate } = harness();
    await gate("git ");
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Git approval: ON", "info");
    await gate("git off");
    await gate("git invalid");
    expect(ctx.ui.notify).toHaveBeenLastCalledWith(
      "Usage: /gate on|off | git [on|off] | jev [on|off] | log",
      "error",
    );
    await gate("git  ");
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Git approval: OFF", "info");
    await run("git commit");
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });

  it.each([
    ["on extra", "error"],
    ["off extra", "error"],
    ["all off", "error"],
    ["git invalid", "error"],
    ["git off extra", "error"],
  ])("shows usage without changing state for %j", async (args, level) => {
    const { gate, ctx, run } = harness();
    await gate(args);
    expect(ctx.ui.notify).toHaveBeenLastCalledWith(
      "Usage: /gate on|off | git [on|off] | jev [on|off] | log",
      level,
    );
    await run("git commit");
    expect(ctx.ui.confirm).toHaveBeenCalledOnce();
  });

  it("completes the Git rule and its explicit on/off values", () => {
    const { gateCommand } = harness();
    expect(gateCommand?.getArgumentCompletions("")).toEqual([
      { value: "on", label: "on" },
      { value: "off", label: "off" },
      { value: "git", label: "git" },
      { value: "jev", label: "jev" },
      { value: "log", label: "log" },
    ]);
    expect(gateCommand?.getArgumentCompletions("g")).toEqual([{ value: "git", label: "git" }]);
    expect(gateCommand?.getArgumentCompletions("git ")).toEqual([
      { value: "git on", label: "git on" },
      { value: "git off", label: "git off" },
    ]);
    expect(gateCommand?.getArgumentCompletions(" GIT ON")).toEqual([
      { value: "git on", label: "git on" },
    ]);
    expect(gateCommand?.getArgumentCompletions("invalid")).toBeNull();
  });

  it("does not resolve dynamic Git executables or wrappers", async () => {
    const { run, ctx } = harness();
    await run('"$GIT" reset --hard');
    await run("env git reset --hard");
    await run("bash -c 'git reset --hard'");
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });
});
