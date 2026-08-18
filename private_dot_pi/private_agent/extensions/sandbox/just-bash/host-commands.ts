import { latin1FromBytes, type ByteString, type Command, type ExecResult } from "just-bash";
import { createRequire } from "node:module";
import type { JustBashConfig } from "./config.ts";

const require = createRequire(import.meta.url);
const { spawn } = require("node:child_process") as typeof import("node:child_process");

// Env vars that just-bash/shell manage and that must never be forwarded as-is
// to a host child: they describe the *virtual* shell, not the real host cwd/dir.
const HOST_ENV_BLOCKLIST = new Set(["OLDPWD", "PWD", "SHLVL", "_"]);

// Proxy env vars that can redirect host child network traffic. Strip them so a
// host command cannot be pointed at an attacker-controlled proxy by the
// host environment. (Mirrors code-yeongyu/pi-sandbox's PROXY_KEYS set.)
const HOST_ENV_PROXY_BLOCKLIST = new Set([
  "HTTP_PROXY",
  "HTTPS_PROXY",
  "ALL_PROXY",
  "NO_PROXY",
  "http_proxy",
  "https_proxy",
  "all_proxy",
  "no_proxy",
  "npm_config_proxy",
  "npm_config_https_proxy",
]);

// Host env var names that commonly hold secrets (API keys, tokens, cloud creds).
// Host commands run fully unsandboxed, so leaking these lets an injected
// command exfiltrate them over the network. (Pattern adapted from code-yeongyu/pi-sandbox.)
const HOST_ENV_SECRET_PATTERN =
  /(_KEY|_TOKEN|_SECRET|_PASSWORD|_PASSWD|^SSH_AUTH_SOCK$|^AWS_.+|^GCP_.+|^GOOGLE_APPLICATION_CREDENTIALS$)/i;

export function normalizeHostCommands(entries: JustBashConfig["hostCommands"]): string[] {
  if (!Array.isArray(entries)) return [];
  return Array.from(
    new Set(
      entries
        .filter((entry): entry is string => typeof entry === "string")
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0 && isBareCommandName(entry)),
    ),
  );
}

// A bare command name: alphanumeric with optional internal `.`, `-`, `_`
// separators — never leading/trailing punctuation and never pure punctuation.
// Rejects ".", "..", "---", ".git", "123." etc. (not real binaries; they would
// only fail at spawn or collide with shell forms like `.`/`source`). The
// charset still bans path separators and shell metacharacters. All real
// command names (node, git, npm, python3.11, gcc-13, 7z, 2to3, ...) pass.
function isBareCommandName(value: string): boolean {
  return /^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$/.test(value);
}

export function createHostCommands(commandNames: string[]): Command[] {
  return commandNames.map((commandName) => ({
    name: commandName,
    trusted: true,
    async execute(args, ctx) {
      // Pass ctx.exportedEnv (NOT ctx.env): a real host child must inherit only
      // the shell's EXPORTED variables plus command-prefix assignments, matching
      // bash semantics. just-bash's ctx.env is the full variable table, so using
      // it would leak non-exported shell locals (e.g. `FOO=bar; cmd` without
      // `export`) to the unsandboxed host process. ctx.exportedEnv is the union
      // of permanently exported vars and tempExportedVars (prefix assignments),
      // built by the interpreter's buildExportedEnv().
      return executeHostCommand(commandName, args, ctx.cwd, ctx.exportedEnv, ctx.stdin, ctx.signal);
    },
  }));
}

function isUnsafeHostEnvKey(key: string): boolean {
  return (
    HOST_ENV_BLOCKLIST.has(key) ||
    HOST_ENV_PROXY_BLOCKLIST.has(key) ||
    HOST_ENV_SECRET_PATTERN.test(key)
  );
}

function buildHostCommandEnv(
  exportedEnv: Readonly<Record<string, string>> | undefined,
  cwd: string,
): NodeJS.ProcessEnv {
  // Start from the host environment but drop proxy/secret keys: host
  // commands run fully unsandboxed, so forwarding secrets would let an injected
  // command exfiltrate them, and forwarding a proxy var would let it reroute
  // traffic to an attacker-controlled host.
  const out: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (value === undefined || isUnsafeHostEnvKey(key)) continue;
    out[key] = value;
  }

  // Overlay the shell's EXPORTED variables only. This mirrors bash child-process
  // inheritance: permanently exported vars plus command-prefix assignments
  // (just-bash tracks the latter as tempExportedVars and includes them in
  // ctx.exportedEnv). Overlaying the full ctx.env instead would leak
  // non-exported shell locals to the real host process. PATH is forced to the
  // host PATH below regardless, so a shell PATH override cannot drive host
  // binary resolution (it must not point at just-bash's virtual bin dir).
  for (const [key, value] of Object.entries(exportedEnv ?? {})) {
    if (isUnsafeHostEnvKey(key)) continue;
    out[key] = value;
  }

  out.PATH = process.env.PATH;
  out.PWD = cwd;
  if (out.GIT_PAGER === undefined) out.GIT_PAGER = "cat";
  if (out.PAGER === undefined) out.PAGER = "cat";
  return out;
}

async function executeHostCommand(
  commandName: string,
  args: string[],
  cwd: string,
  env: Readonly<Record<string, string>> | undefined,
  stdin: ByteString,
  signal?: AbortSignal,
): Promise<ExecResult> {
  return new Promise((resolve) => {
    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    let settled = false;

    const finish = (result: ExecResult) => {
      if (settled) return;
      settled = true;
      signal?.removeEventListener("abort", onAbort);
      resolve(result);
    };

    const child = spawn(commandName, args, {
      cwd,
      env: buildHostCommandEnv(env, cwd),
      detached: process.platform !== "win32",
      stdio: ["pipe", "pipe", "pipe"],
    });

    const killChild = () => {
      if (!child.pid) return;
      if (process.platform !== "win32") {
        try {
          process.kill(-child.pid, "SIGKILL");
          return;
        } catch {
          // Fall through to direct child kill.
        }
      }
      child.kill("SIGKILL");
    };

    const onAbort = () => {
      killChild();
    };

    if (signal) {
      if (signal.aborted) onAbort();
      else signal.addEventListener("abort", onAbort, { once: true });
    }

    child.stdout?.on("data", (chunk) => {
      stdoutChunks.push(Buffer.from(chunk));
    });
    child.stderr?.on("data", (chunk) => {
      stderrChunks.push(Buffer.from(chunk));
    });

    child.on("error", (error) => {
      const errno = error as NodeJS.ErrnoException;
      finish({
        stdout: "",
        stderr:
          errno.code === "ENOENT"
            ? `bash: ${commandName}: command not found\n`
            : `bash: ${commandName}: ${error instanceof Error ? error.message : String(error)}\n`,
        exitCode: errno.code === "ENOENT" ? 127 : 1,
      });
    });

    child.on("close", (code) => {
      finish({
        // Carry raw bytes through as a latin1 byte buffer (stdoutKind: "bytes")
        // so binary output (git cat-file --batch, gzipped blobs, ...) survives
        // the just-bash pipeline instead of being mojibake'd by a UTF-8 decode
        // here. Bash.exec() re-decodes valid UTF-8 at its output boundary;
        // invalid UTF-8 stays byte-clean through to onData.
        stdout: Buffer.concat(stdoutChunks).toString("latin1"),
        stderr: Buffer.concat(stderrChunks).toString("latin1"),
        exitCode: code ?? (signal?.aborted ? 130 : 1),
        stdoutKind: "bytes",
        stdoutEncoding: "binary",
      });
    });

    // A child that exits before reading stdin (e.g. `git apply` on a bad patch,
    // or `gh` ignoring piped input) will close the write end and emit EPIPE on
    // the still-pending write. Without a listener Node would crash the process
    // with an uncaught 'error' event; swallow it as an expected condition.
    child.stdin?.on("error", () => {});
    child.stdin?.end(Buffer.from(latin1FromBytes(stdin), "latin1"));
  });
}
