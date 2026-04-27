// Copied from: https://github.com/telagod/oh-pi/blob/33c427394b8459f963fe56f7f3150d3fddef41f6/pi-package/extensions/safe-guard.ts

/**
 * oh-pi Safe Guard Extension
 *
 * Combines destructive command confirmation + protected paths in one extension.
 */
import type { ExtensionAPI, ExtensionUIContext } from "@mariozechner/pi-coding-agent";
import { spawn } from "node:child_process";

export const DANGEROUS_PATTERNS = [
  /\brm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|.*-rf\b|.*--force\b)/,
  /\bsudo\s+rm\b/,
  /\b(DROP|TRUNCATE|DELETE\s+FROM)\b/i,
  /\bchmod\s+777\b/,
  /\bmkfs\b/,
  /\bdd\s+if=/,
  />\s*\/dev\/sd[a-z]/,
];

export const PROTECTED_PATHS = [".env", ".git/", "node_modules/", ".pi/", "id_rsa", ".ssh/"];

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
    // Check bash commands for dangerous patterns
    if (event.toolName === "bash") {
      const cmd = (event.input as { command?: string }).command ?? "";
      const match = DANGEROUS_PATTERNS.find((p) => p.test(cmd));
      if (match && ctx.hasUI) {
        notifier.notify("Pi Danger Approval Needed", cmd);
        const ok = await ctx.ui.confirm("⚠️ Dangerous Command", `Execute: ${cmd}?`);
        if (!ok) {
          ctx.abort();
          return { block: true, reason: "Blocked by user" };
        }
      }
    }

    // Check write/edit for protected paths
    if (event.toolName === "write" || event.toolName === "edit") {
      const path = (event.input as { path?: string }).path ?? "";
      const hit = PROTECTED_PATHS.find((p) => path.includes(p));
      if (hit) {
        if (ctx.hasUI) {
          notifier.notify("Pi Path Approval Needed", path);
          const ok = await ctx.ui.confirm("🛡️ Protected Path", `Allow write to ${path}?`);
          if (!ok) {
            ctx.abort();
            return { block: true, reason: `Protected path: ${hit}` };
          }
        } else {
          return { block: true, reason: `Protected path: ${hit}` };
        }
      }
    }
  });
}
