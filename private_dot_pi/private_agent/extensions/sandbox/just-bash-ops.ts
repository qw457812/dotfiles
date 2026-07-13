import type { BashOperations } from "@earendil-works/pi-coding-agent";
import {
  Bash,
  getCommandNames,
  getJavaScriptCommandNames,
  getNetworkCommandNames,
  getPythonCommandNames,
} from "just-bash";
import { existsSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { resolve } from "node:path";
import type { JustBashConfig } from "./just-bash/config.ts";
import { createJustBashFs } from "./just-bash/filesystem.ts";
import { createHostCommands, normalizeHostCommands } from "./just-bash/host-commands.ts";
import {
  assertReadonlyEntryExists,
  assertReadonlyTargetExists,
  assertReadonlyWriteTargetHasParent,
} from "./just-bash/read-only-host-fs.ts";

export { formatAllowedUrlPrefixes } from "./just-bash/config.ts";
export type { JustBashConfig, JustBashFilesystemConfig } from "./just-bash/config.ts";

const JUST_BASH_VIRTUAL_SYSTEM_PATH = "/usr/bin:/bin";

export const __testing = {
  assertReadonlyEntryExists,
  assertReadonlyTargetExists,
  assertReadonlyWriteTargetHasParent,
};

export function createJustBashOps(
  root: string,
  config: JustBashConfig | undefined,
): BashOperations {
  const policyRoot = resolve(root);
  const filesystem = config?.filesystem;
  const hostCommandNames = normalizeHostCommands(config?.hostCommands);
  const hostCommands = createHostCommands(hostCommandNames);
  // Command discovery is two-layered: (1) just-bash's Bash constructor only
  // registers a command in its internal registry when its option is set
  // (python/javascript/network/custom), and (2) THIS extension overrides
  // /usr/bin and /bin with a VirtualBinFs whose readdir/exists/stat are driven
  // solely by this list. Because VirtualBinFs always mounts /usr/bin, just-bash's
  // registry-only fallback (command-resolution.ts, taken when /usr/bin is
  // absent) NEVER runs here — so a command missing from virtualBinCommands is
  // invisible even if it is registered. Therefore every opt-in command set must
  // be mirrored into virtualBinCommands with the SAME condition as the
  // `new Bash({...})` call below.
  const virtualBinCommands = Array.from(
    new Set([
      ...getCommandNames(),
      ...(config?.network !== undefined ? getNetworkCommandNames() : []),
      ...(config?.python === true ? getPythonCommandNames() : []),
      ...(config?.javascript ? getJavaScriptCommandNames() : []),
      ...hostCommandNames,
    ]),
  );

  return {
    async exec(command, cwd, { onData, signal, timeout, env }) {
      if (!existsSync(policyRoot)) {
        throw new Error(
          `Working directory does not exist: ${policyRoot}\nCannot execute bash commands.`,
        );
      }

      const virtualCwd = resolve(cwd);
      if (!existsSync(cwd)) {
        throw new Error(`Working directory does not exist: ${cwd}\nCannot execute bash commands.`);
      }
      if (signal?.aborted) {
        throw new Error("aborted");
      }

      const controller = new AbortController();
      const onAbort = () => controller.abort(signal?.reason);
      if (signal) {
        if (signal.aborted) controller.abort(signal.reason);
        else signal.addEventListener("abort", onAbort, { once: true });
      }

      let timedOut = false;
      const timeoutHandle =
        timeout !== undefined && timeout > 0
          ? setTimeout(() => {
              timedOut = true;
              controller.abort(new Error(`timeout:${timeout}`));
            }, timeout * 1000)
          : undefined;

      try {
        const fs = createJustBashFs(policyRoot, filesystem, virtualBinCommands);
        const bash = new Bash({
          fs,
          cwd: virtualCwd,
          env: toStringEnv(env),
          ...(config?.network !== undefined ? { network: config.network } : {}),
          ...(config?.python === true ? { python: true } : {}),
          ...(config?.javascript ? { javascript: config.javascript } : {}),
          ...(hostCommands.length > 0
            ? {
                customCommands: hostCommands,
                // defenseInDepth is disabled for this Bash instance because of
                // a just-bash 3.x bug: with DiD ON, *any* command-prefix
                // assignment (`VAR=value cmd ...`, including builtins) trips a
                // `dynamic import of Node.js builtin 'node:module'` violation.
                // That breaks the common `GIT_AUTHOR_NAME=... git commit`
                // idiom, so DiD must be off whenever host commands are
                // registered. (The import is just-bash's own ESM-loader hook
                // used to enforce DiD; see its defense-in-depth-box.ts.)
                //
                // NOTE on PATH shadowing: with DiD OFF, just-bash resolves
                // commands via PATH *before* dispatching to custom commands.
                // `PATH=<writable-dir> <host-cmd>` can therefore resolve
                // to a same-named file in that dir instead of the registered
                // command. That file is NOT executed on the host — just-bash
                // reads it, strips the shebang, and interprets it as bash
                // *inside the sandbox* (executeUserScript). It is NOT spawned
                // on the host, so it cannot bypass the read-only host FS
                // (writes still throw EROFS) or the network policy. denyRead
                // is still enforced by DenyFilteredFs for sandboxed commands,
                // so PATH shadowing does not bypass the just-bash read policy;
                // the only effect is that the host command silently runs
                // a sandboxed same-named script instead of the host binary.
                // buildHostCommandEnv ignores the shell PATH for the real spawn
                // (always process.env.PATH).
                // The practical risk is reliability/confusion: an agent may
                // believe it ran host `node` while actually running a sandboxed
                // same-named script. Mitigation: don't allow adversaries to
                // write same-named executables into PATH dirs.
                // TODO: drop `defenseInDepth: false` once just-bash fixes the
                //       prefix-assignment import so DiD can stay on.
                defenseInDepth: false,
              }
            : {}),
        });
        // Let Bash.exec's output-boundary decode (logResult ->
        // decodeBinaryToUtf8) run normally. It decodes valid-UTF-8 byte
        // sequences in the latin1 pipeline buffer back to Unicode (e.g. host
        // bytes c3 a9 -> U+00E9), and Buffer.from(result.stdout, "utf8") below
        // re-encodes that to the original bytes — so valid UTF-8 from both host
        // commands and builtins round-trips correctly. Non-UTF-8 binary output
        // is utf8-expanded (an inherent limitation of just-bash's string-based
        // pipeline, since byte 0xE9 and codepoint U+00E9 are indistinguishable
        // once collapsed into a JS string); that only affects raw binary from a
        // host command, never the text output of git/gh/node.
        const result = await bash.exec(command, { signal: controller.signal });
        if (result.stdout.length > 0) onData(Buffer.from(result.stdout, "utf8"));
        if (result.stderr.length > 0) onData(Buffer.from(result.stderr, "utf8"));
        if (signal?.aborted) throw new Error("aborted");
        if (timedOut) throw new Error(`timeout:${timeout}`);
        return { exitCode: result.exitCode };
      } catch (err) {
        if (signal?.aborted) throw new Error("aborted");
        if (timedOut) throw new Error(`timeout:${timeout}`);
        throw err;
      } finally {
        if (timeoutHandle) clearTimeout(timeoutHandle);
        signal?.removeEventListener("abort", onAbort);
      }
    },
  };
}

function toStringEnv(env: NodeJS.ProcessEnv | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(env ?? {})) {
    if (typeof value === "string") out[key] = value;
  }
  // just-bash defaults HOME to "/", but this backend exposes the host path
  // namespace. Keep shell $HOME aligned with config "~" expansion so commands
  // like `$HOME/.ssh/known_hosts` work with allowRead overrides.
  if (out.HOME === undefined || out.HOME.length === 0) out.HOME = homedir();
  // Keep shell $TMPDIR aligned with the default writable temp root so commands
  // like `mktemp` and `$TMPDIR/file` have a discoverable writable directory.
  if (out.TMPDIR === undefined || out.TMPDIR.length === 0) out.TMPDIR = tmpdir();
  // With host-wide read access, forwarding the real host PATH makes just-bash
  // discover host ELF/Mach-O binaries and try to parse them as shell scripts.
  // Keep command lookup through the virtual /usr/bin and /bin mounts created by
  // createJustBashFs().
  out.PATH = JUST_BASH_VIRTUAL_SYSTEM_PATH;
  return out;
}
