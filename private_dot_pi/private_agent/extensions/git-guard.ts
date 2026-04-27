// Ref: https://github.com/telagod/oh-pi/blob/7e59d1bcbfe1af837494a65d759d047a6474b103/pi-package/extensions/git-guard.ts

/**
 * Git Guard Extension
 *
 * Combines mutating git command confirmation + dirty-repo-guard.
 */
import type { ExtensionAPI, ExtensionUIContext } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";

const GUARDED_GIT_PATTERN = /\bgit\s+(?<subcommand>add|commit|push|pull|merge|rebase|reset|checkout|switch|stash|cherry-pick|revert|restore|clean)\b/;

const notify = (title: string, body: string): void => {
  if (process.platform === "darwin") {
    const script = `on run argv
display notification (item 2 of argv) with title (item 1 of argv)
end run`;
    const proc = spawn("osascript", ["-e", script, "--", title, body], { stdio: "ignore" });
    proc.once("error", () => {});
    proc.unref();
  } else if (process.env.TERMUX_VERSION) {
    const proc = spawn("termux-notification", ["-t", title, "-c", body], { stdio: "ignore" });
    proc.once("error", () => {});
    proc.unref();
  } else if (process.env.KITTY_WINDOW_ID) {
    process.stdout.write(`\x1b]99;i=1:d=0;${title}\x1b\\`);
    process.stdout.write(`\x1b]99;i=1:p=body;${body}\x1b\\`);
  } else {
    process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
  }
};

type FocusTracker = {
  // true = focused, false = unfocused, undefined = unknown
  isFocused: () => boolean | undefined;
  dispose: () => void;
};

const createTerminalFocusTracker = (ui: Pick<ExtensionUIContext, "onTerminalInput">): FocusTracker | undefined => {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    return undefined;
  }

  const FOCUS_REPORTING_ENABLE = "\x1b[?1004h";
  const FOCUS_REPORTING_DISABLE = "\x1b[?1004l";
  const FOCUS_IN = "\x1b[I";
  const FOCUS_OUT = "\x1b[O";

  let focused: boolean | undefined;

  process.stdout.write(FOCUS_REPORTING_ENABLE);
  const unsubTermInput = ui.onTerminalInput((data) => {
    if (data === FOCUS_IN) {
      focused = true;
    } else if (data === FOCUS_OUT) {
      focused = false;
    }
  });

  return {
    isFocused: () => focused,
    dispose: () => {
      unsubTermInput();
      process.stdout.write(FOCUS_REPORTING_DISABLE);
    },
  };
};

type FocusAwareNotifier = {
  notify: (title: string, body: string) => void;
};

const createFocusAwareNotifier = (pi: ExtensionAPI): FocusAwareNotifier => {
  let focusTracker: FocusTracker | undefined;

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) {
      return;
    }

    focusTracker = createTerminalFocusTracker(ctx.ui);
  });

  pi.on("session_shutdown", async () => {
    focusTracker?.dispose();
    focusTracker = undefined;
  });

  return {
    notify: (title: string, body: string) => {
      if (!focusTracker?.isFocused()) {
        notify(title, body);
      }
    },
  };
};

export default function (pi: ExtensionAPI) {
  const notifier = createFocusAwareNotifier(pi);

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;

    const command = (event.input as { command?: string }).command ?? "";
    const subcommand = command.match(GUARDED_GIT_PATTERN)?.groups?.subcommand;
    if (!subcommand) return;

    if (!ctx.hasUI) {
      return { block: true, reason: `Git ${subcommand} requires user confirmation` };
    }

    notifier.notify("Pi Git Approval Needed", command);
    const ok = await ctx.ui.confirm(`🔐 Allow git ${subcommand}?`, command);
    if (!ok) {
      ctx.abort();
      return { block: true, reason: "Blocked by user" };
    }
  });

  // Warn on dirty repo at session start
  pi.on("session_start", async (_event, ctx) => {
    try {
      const { stdout } = await pi.exec("git", ["status", "--porcelain"]);
      if (stdout.trim() && ctx.hasUI) {
        const lines = stdout.trim().split("\n").length;
        ctx.ui.notify(`⚠️ Dirty repo: ${lines} uncommitted change(s)`, "warning");
      }
    } catch { /* not a git repo, ignore */ }
  });
}
