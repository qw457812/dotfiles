import { tmpdir } from "node:os";
import { posix } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import permissionGate from "../extensions/permission-gate.ts";
import dirtyRepoGuard from "../extensions/dirty-repo-guard.ts";
import safeGuard from "../extensions/safe-guard.ts";
import { initializeBashParser } from "../lib/bash-parser.ts";

type Handler = (
  event: { toolName: string; input: { command?: string; path?: string } },
  ctx: {
    cwd: string;
    hasUI: boolean;
    ui: { confirm: ReturnType<typeof vi.fn>; notify: ReturnType<typeof vi.fn> };
    abort: ReturnType<typeof vi.fn>;
  },
) => Promise<{ block: boolean; reason: string } | undefined>;

type GateCommand = {
  handler: (args: string, ctx: Parameters<Handler>[1]) => Promise<void>;
  getArgumentCompletions: (prefix: string) => { value: string; label: string }[] | null;
};

function harness(approved = true, hasUI = true, extension = permissionGate) {
  let handler: Handler | undefined;
  let gateCommand: GateCommand | undefined;
  const emit = vi.fn();
  extension({
    on: (event: string, callback: Handler) => {
      if (event === "tool_call") handler = callback;
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
  };
  return {
    ctx,
    emit,
    gateCommand,
    gate: (args: string) => {
      if (!gateCommand) throw new Error("Gate command not registered");
      return gateCommand.handler(args, ctx);
    },
    run: (command: string, toolName = "bash") => {
      if (!handler) throw new Error("Handler not registered");
      return handler({ toolName, input: { command, path: command } }, ctx);
    },
  };
}

const PARSE_ERROR_CASES = [
  'echo "unterminated',
  "if true; then echo ok",
  "echo ok >",
  'rm -rf /tmp/file; echo "unterminated',
];

const APPROVAL_CASES = [
  'sudo rm -rf /; echo "unterminated',
  "sudo echo hello",
  "/usr/bin/sudo -u root true",
  "'sudo' true",
  "rm -f file",
  "rm -r directory",
  "rm -Rf directory",
  "rm --force file",
  "rm --recursive directory",
  "rm -rf /tmp",
  "rm /tmp/",
  "rm -- /tmp",
  "rm -rf /tmp/.",
  "rm -rf /var/tmp",
  "rm /var/tmp/",
  "rm -rf /tmp/child/..",
  "rm -rf /private/tmp",
  "rm -rf /private/tmp/",
  "rm -rf /private/var/tmp",
  "rm -rf /private/var/tmp/child/..",
  "rm -rf /private/tmp-not-temp/file",
  "rm -rf /private/var/tmp-not-temp/file",
  "rm -rf /private/tmp/../etc/file",
  "rm -rf /private/var/tmp/../../etc/file",
  "rm -rf /private/tmp/file /repo/file",
  "sudo rm -rf /private/tmp/file",
  ...(process.platform === "darwin" ? ["rm /private/tmp", "rm -- /private/var/tmp"] : []),
  `rm -rf ${JSON.stringify(tmpdir())}`,
  "rm -rf /tmp/file /repo/file",
  "rm -rf /repo/file /tmp/file",
  "rm -rf /tmp/file relative.tmp",
  "rm -rf /tmp-not-temp/file",
  "rm -rf /var/tmp-not-temp/file",
  "rm -rf /tmp/../etc/file",
  "rm -rf /tmp/nested/../../etc/file",
  "rm -rf ./tmp/file",
  "rm -rf report.tmp",
  "rm -rf /tmp/*",
  'rm -rf "$TMPDIR/file"',
  'TMPDIR=/tmp rm -rf "$TMPDIR/file"',
  "rm -rf /tmp/file --unknown-option",
  "rm -rf --unknown-option /tmp/file",
  "rm -rf /tmp/file -- /repo/file",
  "rm -rf -- /tmp/file /repo/file",
  "sudo rm -rf /tmp/file",
  "rm -rf /tmp/file; rm -rf /repo/file",
  "rm -rf /tmp/file; git reset --hard",
  "rm -rf /tmp/file >/dev/sda",
  "rm /",
  "rm .",
  "rm ../",
  "rm /tmp/..",
  'rm "$TARGET"',
  "rm *.txt",
  "rm ~/file",
  "mkfs /dev/sda",
  "/sbin/mkfs.ext4 /dev/sda",
  "dd",
  "dd if=input of=output",
  "chmod 2 file",
  "chmod 22 file",
  "chmod 0000777 file",
  "chmod 0004755 file",
  "chmod 0002755 file",
  "chmod +2 file",
  "chmod =0000777 file",
  "chmod 777 file",
  "chmod 0777 file",
  "chmod 666 file",
  "chmod 4755 file",
  "chmod 2755 file",
  "chmod +777 file",
  "chmod o+w file",
  "chmod a=rw file",
  "chmod +w file",
  "chmod u+s file",
  "chmod g=rs file",
  "chmod u+x,o+w file",
  "chmod -R u+w dir",
  "chmod --recursive 755 dir",
  "chmod -R --reference=other file",
  'chmod "$MODE" file',
  'chmod 755 "$TARGET"',
  "chown user file",
  "chgrp group file",
  "echo ok >/dev/sda",
  "echo ok >>'/dev/nvme0n1'",
  "echo ok 2>/dev/disk/by-id/disk",
  "echo ok &>/dev/disk0",
  "echo ok >|/dev/sda",
  "echo ok >&/dev/sda",
  "cat <>/dev/sda",
  'echo ok >"$DEVICE"',
  "echo ok >/dev/./sda",
  "true; rm -rf dir; echo done",
  "true&&rm -f file",
  "rm -rf dir|tee output",
  "(rm -rf dir)",
  "if true; then rm -rf dir; fi",
  "for file in a b; do rm -f file; done",
  'echo "$(rm -rf dir)"',
  "echo `rm -rf dir`",
  "cat <(rm -rf dir)",
  "cat <<EOF\n$(rm -rf dir)\nEOF",
  "TARGET=$(sudo true) echo done",
  "r\\m -rf dir",
  'r"m" -rf dir',
  '"/bin/rm" -rf dir',
];

const CLEAR_CASES = [
  ...PARSE_ERROR_CASES,
  "",
  "  ",
  "rm file",
  "rm -i file",
  "rm -- -rf",
  "rm -- --recursive",
  "rm ./-rf",
  "rm -f /tmp/file",
  "rm -rf /tmp/directory",
  "rm -Rf /var/tmp/directory",
  "rm --force --recursive /tmp/directory",
  "rm -rf -- /tmp/directory",
  "rm -rf /tmp/first /var/tmp/second",
  "rm -rf '/tmp/a b'",
  'rm -rf "/var/tmp/a b"',
  "rm -rf /tmp//directory/",
  "rm -rf /tmp/child/../file",
  "rm -rf /tmp/-rf",
  "rm -rf -- /tmp/--recursive",
  "rm -rf '/tmp/*'",
  `rm -rf ${JSON.stringify(posix.join(tmpdir(), "permission-gate-test-file"))}`,
  "/bin/rm -rf /tmp/directory",
  "true && rm -rf /tmp/directory; echo done",
  "rm -rf /tmp/first; rm -rf /var/tmp/second",
  'echo "$(rm -rf /tmp/directory)"',
  ...(process.platform === "darwin"
    ? [
        "rm -rf /private/tmp/file",
        "rm -rf -- /private/var/tmp/directory",
        "rm -rf /tmp/first /private/tmp/second /private/var/tmp/third",
        "rm -rf '/private/tmp/a b'",
        "rm -rf /private/tmp/child/../file",
      ]
    : []),
  "chmod 0 file",
  "chmod 1 file",
  "chmod 75 file",
  "chmod 0000755 file",
  "chmod 0001755 file",
  "chmod -2 file",
  "chmod -0006000 file",
  "chmod -- -777 file",
  "chmod --reference=other file",
  "chmod --reference 777 file",
  "chmod 755 file",
  "chmod 644 file",
  "chmod u+w file",
  "chmod g+w file",
  "chmod o-w file",
  "chmod u-s file",
  "chmod 1755 file",
  "chmod 755 777",
  "chmod 755 'o+w'",
  "echo sudo rm -rf dir",
  'echo "sudo rm -rf dir; chmod 777 file"',
  "printf '%s' 'mkfs dd if=foo > /dev/sda'",
  "# sudo rm -rf /\necho ok",
  "cat <<'EOF'\n$(rm -rf dir)\nsudo\nEOF",
  "cat <<EOF\nrm -rf dir\nEOF",
  'echo "literal $text rm -rf"',
  "echo 'DROP TABLE x; DELETE FROM x; TRUNCATE x'",
  "echo ok >/dev/null",
  "echo ok >/dev/stdout",
  "echo ok 2>/dev/stderr",
  "echo ok >/dev/fd/1",
  "echo ok 2>&1",
  "echo ok >output",
  "cat </dev/sda",
  "echo /dev/sda",
  "git status",
];

// Deliberate coverage limits: dynamic names, aliases/functions and wrapper strings
// are not resolved, even when their execution could invoke a dangerous command.
const UNRESOLVED_EXECUTABLE_CASES = [
  '"$TOOL" -rf dir',
  "${TOOL} -rf dir",
  "$(printf rm) -rf dir",
  "env rm -rf dir",
  "command rm -rf dir",
  "xargs rm -rf",
  "bash -c 'rm -rf dir'",
  "eval 'rm -rf dir'",
  "alias wipe='rm -rf'; wipe dir",
  "wipe dir",
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
  it.each(APPROVAL_CASES)("asks once and shows the complete command: %s", async (command) => {
    const { run, ctx, emit } = harness();
    expect(await run(command)).toBeUndefined();
    expect(ctx.ui.confirm).toHaveBeenCalledExactlyOnceWith("🔐 Allow this command?", command);
    expect(emit).toHaveBeenCalledWith("my:notification", {
      title: "Pi Danger Approval",
      body: command,
    });
    expect(ctx.abort).not.toHaveBeenCalled();
  });

  it.each([...CLEAR_CASES, ...UNRESOLVED_EXECUTABLE_CASES])("stays silent: %s", async (command) => {
    const { run, ctx, emit } = harness(true, false);
    expect(await run(command)).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(emit).not.toHaveBeenCalled();
  });

  it.each(APPROVAL_CASES)("blocks without UI: %s", async (command) => {
    const { run, ctx, emit } = harness(true, false);
    expect(await run(command)).toEqual({
      block: true,
      reason: "Command requires user confirmation",
    });
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
    expect(emit).not.toHaveBeenCalled();
  });

  it.each(PARSE_ERROR_CASES)("does not prompt for syntax errors alone: %s", async (command) => {
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
        expect(await run("sudo rm -rf /")).toBeUndefined();
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

  it.each(["/private/tmp/file", "/private/var/tmp/file"])(
    "only exempts macOS private temporary descendants: %s",
    async (path) => {
      const { run, ctx } = harness();
      expect(await run(`rm -rf ${path}`)).toBeUndefined();
      expect(ctx.ui.confirm).toHaveBeenCalledTimes(process.platform === "darwin" ? 0 : 1);
    },
  );

  it("does not ask or abort for an exempt temporary deletion even with UI", async () => {
    const { run, ctx, emit } = harness(false);
    expect(await run("rm -rf -- /tmp/permission-gate-test-file")).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
    expect(emit).not.toHaveBeenCalled();
  });

  it("aborts and blocks on denial", async () => {
    const { run, ctx } = harness(false);
    expect(await run("rm -rf dir")).toEqual({ block: true, reason: "Blocked by user" });
    expect(ctx.abort).toHaveBeenCalledOnce();
  });

  it.each(["write", "edit", "read"])("ignores non-bash tools: %s", async (tool) => {
    const { run, ctx } = harness();
    expect(await run("sudo rm -rf /", tool)).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });
});

describe("Permission Gate Git rules", () => {
  it.each(GIT_APPROVAL_CASES)("asks for approval: %s", async (command) => {
    const { run, ctx } = harness();
    expect(await run(command)).toBeUndefined();
    expect(ctx.ui.confirm).toHaveBeenCalledOnce();
    expect(ctx.ui.confirm).toHaveBeenCalledWith("🔐 Allow this command?", command);
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
      reason: "Command requires user confirmation",
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
  it.each([
    "sudo git reset --hard",
    "git reset --hard; rm -rf dir",
    "git commit -m update && git push",
    "git status >/dev/sda",
  ])("parses and confirms once with both extensions loaded: %s", async (command) => {
    const parser = await initializeBashParser();
    const parse = vi.spyOn(parser, "parse");
    try {
      const { run, ctx, emit } = harness(true, true, (pi) => {
        permissionGate(pi);
        dirtyRepoGuard(pi);
      });
      expect(await run(command)).toBeUndefined();
      expect(parse).toHaveBeenCalledOnce();
      expect(ctx.ui.confirm).toHaveBeenCalledExactlyOnceWith("🔐 Allow this command?", command);
      expect(emit).toHaveBeenCalledOnce();
    } finally {
      parse.mockRestore();
    }
  });

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

  it.each([
    "sudo git reset --hard",
    "git status >/dev/sda",
    "git reset --hard; rm -rf dir",
    'git "$ACTION"; rm -rf dir',
    'sudo git "$ACTION"',
    'git "$ACTION" >/dev/sda',
  ])("still confirms other risks with Git rules off: %s", async (command) => {
    const { run, ctx, gate } = harness();
    await gate("git off");
    await run(command);
    expect(ctx.ui.confirm).toHaveBeenCalledExactlyOnceWith("🔐 Allow this command?", command);
  });

  it("does not confirm syntax errors alone when Git rules are off", async () => {
    const { run, ctx, gate } = harness(true, false);
    await gate("git off");
    expect(await run('git merge "unterminated')).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });

  it.each(["rm -rf dir", 'git "$ACTION"; rm -rf dir'])(
    "still blocks without UI with Git rules off: %s",
    async (command) => {
      const { run, ctx, gate } = harness(true, false);
      await gate("git off");
      expect(await run(command)).toEqual({
        block: true,
        reason: "Command requires user confirmation",
      });
      expect(ctx.ui.confirm).not.toHaveBeenCalled();
    },
  );

  it("reports status and rejects invalid gate arguments without changing state", async () => {
    const { run, ctx, gate } = harness();
    await gate("git ");
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Git approval: ON", "info");
    await gate("git off");
    await gate("git invalid");
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Usage: /gate git [on|off]", "error");
    await gate("git  ");
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Git approval: OFF", "info");
    await run("git commit");
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });

  it.each([
    ["", "info"],
    [" ", "info"],
    ["on", "error"],
    ["off", "error"],
    ["all off", "error"],
    ["git invalid", "error"],
    ["git off extra", "error"],
  ])("shows usage without changing state for %j", async (args, level) => {
    const { gate, ctx, run } = harness();
    await gate(args);
    expect(ctx.ui.notify).toHaveBeenLastCalledWith("Usage: /gate git [on|off]", level);
    await run("git commit");
    expect(ctx.ui.confirm).toHaveBeenCalledOnce();
  });

  it("completes the Git rule and its explicit on/off values", () => {
    const { gateCommand } = harness();
    expect(gateCommand?.getArgumentCompletions("")).toEqual([{ value: "git", label: "git" }]);
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

describe("Safe Guard keeps only path protection", () => {
  it("does not duplicate bash confirmation", async () => {
    const { run, ctx } = harness(false, true, safeGuard);
    expect(await run("sudo rm -rf /; echo DROP TABLE")).toBeUndefined();
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
  });

  it.each(["write", "edit"])(
    "preserves protected-path confirmation and denial: %s",
    async (tool) => {
      const { run, ctx } = harness(false, true, safeGuard);
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
    const { run, ctx } = harness(true, false, safeGuard);
    expect(await run("/repo/.env", tool)).toEqual({ block: true, reason: "Protected path: .env" });
    expect(ctx.ui.confirm).not.toHaveBeenCalled();
    expect(ctx.abort).not.toHaveBeenCalled();
  });
});
