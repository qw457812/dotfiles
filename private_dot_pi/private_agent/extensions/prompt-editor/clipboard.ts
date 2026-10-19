import { spawn, spawnSync } from "node:child_process";

const TERMUX_CLIPBOARD_GET = "termux-clipboard-get";
const TERMUX_CLIPBOARD_SET = "termux-clipboard-set";
const CLIPBOARD_READ_MAX_BUFFER_BYTES = 1024 * 1024;
const CLIPBOARD_WRITE_ABORTED_MESSAGE = "clipboard write aborted";
const CLIPBOARD_COMMAND_TIMEOUT_MS = 1000;
const COMMAND_EXISTS_TIMEOUT_MS = 1000;

type ClipboardEditor = {
  setClipboardFn?: (fn: (text: string, signal?: AbortSignal) => unknown) => void;
  setClipboardReadFn?: (fn: () => string | null) => void;
};

export function readMacOSClipboard(): string | null {
  try {
    // Avoid pi-vim's Node/native-addon helper startup on every put. Use an
    // absolute path so a restricted PATH cannot break clipboard reads.
    const result = spawnSync("/usr/bin/pbpaste", ["-Prefer", "txt"], {
      encoding: "utf8",
      env: { ...process.env, LANG: "en_US.UTF-8", LC_ALL: "en_US.UTF-8" },
      maxBuffer: CLIPBOARD_READ_MAX_BUFFER_BYTES,
      stdio: ["ignore", "pipe", "ignore"],
      timeout: CLIPBOARD_COMMAND_TIMEOUT_MS,
    });
    // null lets pi-vim fall back to its unnamed register on failure.
    if (result.error || result.status !== 0 || result.signal) return null;
    return result.stdout ?? "";
  } catch {
    return null;
  }
}

function commandExists(command: string, timeoutMs = COMMAND_EXISTS_TIMEOUT_MS): boolean {
  const result = spawnSync("sh", ["-c", 'command -v "$1" >/dev/null 2>&1', "sh", command], {
    stdio: "ignore",
    timeout: timeoutMs,
    windowsHide: true,
  });
  return !result.error && result.status === 0;
}

function isTermuxClipboardAvailable(): boolean {
  const looksLikeTermux =
    process.platform === "android" || process.env.PREFIX?.includes("com.termux") === true;
  return (
    looksLikeTermux && commandExists(TERMUX_CLIPBOARD_GET) && commandExists(TERMUX_CLIPBOARD_SET)
  );
}

export function readTermuxClipboard(): string | null {
  try {
    const result = spawnSync(TERMUX_CLIPBOARD_GET, [], {
      encoding: "utf8",
      maxBuffer: CLIPBOARD_READ_MAX_BUFFER_BYTES,
      stdio: ["ignore", "pipe", "ignore"],
      timeout: CLIPBOARD_COMMAND_TIMEOUT_MS,
      windowsHide: true,
    });

    if (result.error || result.status !== 0 || result.signal) return null;
    return result.stdout ?? "";
  } catch {
    return null;
  }
}

function getAbortReason(signal: AbortSignal, fallbackMessage = "operation aborted"): Error {
  return signal.reason instanceof Error ? signal.reason : new Error(fallbackMessage);
}

function createTermuxClipboardSpawnError(message: string): Error {
  // pi-vim's clipboard mirror circuit breaker treats spawn-style errors
  // as environment failures. Preserve that shape for Termux:API failures
  // so repeated yanks/deletes stop spawning a broken clipboard helper.
  const error = new Error(message) as NodeJS.ErrnoException;
  error.code = "TERMUX_CLIPBOARD_SET_FAILED";
  error.syscall = `spawn ${TERMUX_CLIPBOARD_SET}`;
  return error;
}

export function writeTermuxClipboard(text: string, signal?: AbortSignal): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    if (signal?.aborted) {
      reject(getAbortReason(signal, CLIPBOARD_WRITE_ABORTED_MESSAGE));
      return;
    }

    let settled = false;
    let child: ReturnType<typeof spawn> | null = null;

    const finish = (error?: unknown) => {
      if (settled) return;
      settled = true;
      signal?.removeEventListener("abort", onAbort);
      if (error) {
        reject(error);
      } else {
        resolve();
      }
    };

    const onAbort = () => {
      try {
        child?.kill("SIGKILL");
      } catch {}
      finish(
        signal
          ? getAbortReason(signal, CLIPBOARD_WRITE_ABORTED_MESSAGE)
          : new Error(CLIPBOARD_WRITE_ABORTED_MESSAGE),
      );
    };

    try {
      child = spawn(TERMUX_CLIPBOARD_SET, [], {
        stdio: ["pipe", "ignore", "ignore"],
        windowsHide: true,
      });
    } catch (error) {
      finish(error);
      return;
    }

    signal?.addEventListener("abort", onAbort, { once: true });

    child.once("error", finish);
    child.once("close", (code) => {
      finish(
        code === 0
          ? undefined
          : createTermuxClipboardSpawnError(`${TERMUX_CLIPBOARD_SET} exited with code ${code}`),
      );
    });

    if (!child.stdin) {
      finish(createTermuxClipboardSpawnError(`${TERMUX_CLIPBOARD_SET} stdin unavailable`));
      return;
    }

    child.stdin.on("error", (error) => {
      finish(
        signal?.aborted
          ? getAbortReason(signal, CLIPBOARD_WRITE_ABORTED_MESSAGE)
          : createTermuxClipboardSpawnError(
              `${TERMUX_CLIPBOARD_SET} stdin error: ${error.message}`,
            ),
      );
    });
    child.stdin.end(text);
  });
}

export function installClipboardBridge(editor: ClipboardEditor): void {
  if (process.platform === "darwin") {
    editor.setClipboardReadFn?.(readMacOSClipboard);
    return;
  }
  if (!isTermuxClipboardAvailable()) return;

  // pi-vim's default clipboard helper uses @mariozechner/clipboard. In
  // Termux that often cannot read Android's clipboard, so normal-mode `p`
  // falls back to pi-vim's unnamed register (for example the last `yy`).
  // Use Termux:API directly so `p` sees text copied outside pi.
  editor.setClipboardReadFn?.(readTermuxClipboard);
  editor.setClipboardFn?.(writeTermuxClipboard);
}
