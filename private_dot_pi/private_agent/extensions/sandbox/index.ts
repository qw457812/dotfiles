// Ref:
// - https://github.com/badlogic/pi-mono/blob/82ecc1300f1649388c346568c7a1b7978ec610d3/packages/coding-agent/examples/extensions/sandbox/index.ts
// - https://github.com/dannote/dot-pi/blob/a8f7711ddcf7ca8f2addfe1cf84c77b56a62987a/extensions/sandbox/index.ts
// - https://github.com/aldoborrero/pi-agent-kit/blob/c990b5c4b3927c5d0886911f0c22981eb5e54db6/extensions/sandbox/index.ts
// - https://github.com/anthropic-experimental/sandbox-runtime

// NOTE: @anthropic-ai/sandbox-runtime is pinned at >=0.0.52 (migrated from 0.0.26).
// Versions <0.0.43 lack resolveParentProxy() — the sandbox proxy cannot chain through
// the user's upstream HTTP_PROXY/HTTPS_PROXY, breaking network access behind firewalls/proxies.

// TODO:
// 1. Ask the user after a sandbox violation (with an option to remember for the session)
//    - Re-run unsandboxed commands
//    - Re-run sandboxed commands with updated SandboxConfig
// 2. Show the count of sandbox violations via `ctx.ui.setStatus`
// 3. Use [vercel-labs/just-bash](https://github.com/vercel-labs/just-bash) on Termux (Android)
//    where @anthropic-ai/sandbox-runtime is not supported
// 4. Consider adding `allowUnsandboxedCommands`: Allow commands to run outside the sandbox via the `dangerouslyDisableSandbox` parameter
//
// Ref:
// - https://github.com/carderne/pi-sandbox
// - https://github.com/tuansondinh/pi-claude-sandbox
// - https://github.com/sionic-ai/pi-justbash-sandbox
// - https://github.com/code-yeongyu/pi-sandbox (just-bash)
// - https://github.com/qw457812/claude-code-sourcemap (`excludedCommands`)

// Alternative sandbox runtimes:
// - https://github.com/afshinm/zerobox
// - https://github.com/always-further/nono
//   see nono's pre-built profiles for reference sandbox configurations

/**
 * Sandbox Extension - OS-level sandboxing for bash commands
 *
 * Uses @anthropic-ai/sandbox-runtime to enforce filesystem and network
 * restrictions on bash commands at the OS level (sandbox-exec on macOS,
 * bubblewrap on Linux).
 *
 * Note: this example intentionally overrides the built-in `bash` tool to show
 * how built-in tools can be replaced. Alternatively, you could sandbox `bash`
 * via `tool_call` input mutation without replacing the tool.
 *
 * Config files (merged, project takes precedence):
 * - ~/.pi/agent/extensions/sandbox.json (global)
 * - <cwd>/.pi/sandbox.json (project-local)
 *
 * Example .pi/sandbox.json:
 * ```json
 * {
 *   "enabled": true,
 *   "backend": "sandboxRuntime",
 *   "excludedCommands": ["gh:*", "docker:*"],
 *   "sandboxRuntime": {
 *     "excludedCommands": [],
 *     "network": {
 *       "allowedDomains": ["github.com", "*.github.com"],
 *       "deniedDomains": []
 *     },
 *     "filesystem": {
 *       "allowRead": ["~/.ssh/known_hosts"],
 *       "denyRead": ["~/.ssh", "~/.aws"],
 *       "allowWrite": [".", "/tmp"],
 *       "denyWrite": [".env"]
 *     }
 *   },
 *   "justBash": {
 *     "excludedCommands": ["bash checkout.sh:*"],
 *     "network": {
 *       "allowedUrlPrefixes": ["https://github.com"]
 *     },
 *     "filesystem": {
 *       "allowWrite": [".", "/tmp"]
 *     },
 *     "python": true,
 *     "javascript": true,
 *     "hostCommands": ["git"]
 *   }
 * }
 * ```
 *
 * Usage:
 * - `pi -e ./sandbox` - sandbox enabled with default/config settings
 * - `pi -e ./sandbox --no-sandbox` - disable sandboxing
 * - `/sandbox` - show current sandbox configuration
 *
 * Setup:
 * 1. Copy sandbox/ directory to ~/.pi/agent/extensions/
 * 2. Run `npm install` in ~/.pi/agent/extensions/sandbox/
 *
 * Linux also requires: bubblewrap, socat, ripgrep
 */

import {
  SandboxManager,
  type FilesystemConfig as RuntimeFilesystemConfig,
  type NetworkConfig as RuntimeNetworkConfig,
  type SandboxAskCallback,
  type SandboxRuntimeConfig,
} from "@anthropic-ai/sandbox-runtime";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  CONFIG_DIR_NAME,
  createBashTool,
  createLocalBashOperations,
  getAgentDir,
  type BashOperations,
} from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, resolve, sep } from "node:path";
import { initializeExcludedCommandMatcher, matchExcludedCommand } from "./excluded-commands.ts";
import {
  createJustBashOps,
  formatAllowedUrlPrefixes,
  type JustBashConfig,
} from "./just-bash-ops.ts";

type Backend = "sandboxRuntime" | "justBash";

interface SandboxRuntimeBackendConfig extends Omit<SandboxRuntimeConfig, "network" | "filesystem"> {
  excludedCommands?: string[];
  network?: RuntimeNetworkConfig;
  filesystem?: RuntimeFilesystemConfig;
}

interface JustBashBackendConfig extends JustBashConfig {
  excludedCommands?: string[];
}

interface SandboxConfig {
  enabled?: boolean;
  /** Explicit backend override. Omit for auto (justBash on Termux/Android, sandboxRuntime otherwise). */
  backend?: Backend;
  /** Shared exclusion list applied to BOTH backends. */
  excludedCommands?: string[];
  sandboxRuntime?: SandboxRuntimeBackendConfig;
  justBash?: JustBashBackendConfig;
}

export const DEFAULT_CONFIG: SandboxConfig = {
  enabled: true,
  excludedCommands: [],
  sandboxRuntime: {
    network: {
      allowedDomains: [
        "npmjs.org",
        "*.npmjs.org",
        "registry.npmjs.org",
        "registry.yarnpkg.com",
        "pypi.org",
        "*.pypi.org",
        "github.com",
        "*.github.com",
        "api.github.com",
        "raw.githubusercontent.com",
      ],
      deniedDomains: [],
    },
    filesystem: {
      denyRead: ["~/.ssh", "~/.aws", "~/.gnupg"],
      allowWrite: [".", "/tmp"],
      denyWrite: [".env", ".env.*", "*.pem", "*.key"],
    },
  },
  justBash: {
    filesystem: {
      allowWrite: [".", "/tmp"],
    },
  },
};

// Copied from: https://github.com/earendil-works/pi/blob/3e9f7174456b5789a1c16398782c683d48321741/packages/coding-agent/src/utils/json.ts
/** Strip `//` line comments and trailing commas from JSON, leaving string literals untouched. */
function stripJsonComments(input: string): string {
  return input
    .replace(/"(?:\\.|[^"\\])*"|\/\/[^\n]*/g, (m) => (m[0] === '"' ? m : ""))
    .replace(/"(?:\\.|[^"\\])*"|,(\s*[}\]])/g, (m, tail) => tail ?? (m[0] === '"' ? m : ""));
}

export function loadConfig(cwd: string): SandboxConfig {
  const projectConfigPath = join(cwd, CONFIG_DIR_NAME, "sandbox.json");
  const globalConfigPath = join(getAgentDir(), "extensions", "sandbox.json");

  let globalConfig: Partial<SandboxConfig> = {};
  let projectConfig: Partial<SandboxConfig> = {};

  if (existsSync(globalConfigPath)) {
    try {
      globalConfig = JSON.parse(stripJsonComments(readFileSync(globalConfigPath, "utf-8")));
    } catch (e) {
      console.error(`Warning: Could not parse ${globalConfigPath}: ${e}`);
    }
  }

  if (existsSync(projectConfigPath)) {
    try {
      projectConfig = JSON.parse(stripJsonComments(readFileSync(projectConfigPath, "utf-8")));
    } catch (e) {
      console.error(`Warning: Could not parse ${projectConfigPath}: ${e}`);
    }
  }

  return deepMerge(deepMerge(DEFAULT_CONFIG, globalConfig), projectConfig);
}

export function resolveBackend(config: SandboxConfig): Backend {
  if (config.backend === "sandboxRuntime" || config.backend === "justBash") {
    return config.backend;
  }
  return isTermux() ? "justBash" : "sandboxRuntime";
}

/** Shared (top-level) excludedCommands ∪ the active backend's excludedCommands. */
export function effectiveExcludedCommands(config: SandboxConfig, backend: Backend): string[] {
  const shared = config.excludedCommands ?? [];
  const specific = config[backend]?.excludedCommands ?? [];
  return Array.from(new Set([...shared, ...specific]));
}

function hasExcludedCommands(config: SandboxConfig, backend: Backend): boolean {
  return effectiveExcludedCommands(config, backend).length > 0;
}

function mergeOptional<T extends object>(
  base: T | undefined,
  overrides: T | undefined,
): T | undefined {
  if (!base) return overrides;
  if (!overrides) return base;
  return { ...base, ...overrides };
}

export function deepMerge(base: SandboxConfig, overrides: Partial<SandboxConfig>): SandboxConfig {
  const result: SandboxConfig = { ...base };

  if (overrides.enabled !== undefined) result.enabled = overrides.enabled;
  if (overrides.backend !== undefined) result.backend = overrides.backend;
  if (overrides.excludedCommands !== undefined)
    result.excludedCommands = overrides.excludedCommands;

  if (overrides.sandboxRuntime) {
    const b = base.sandboxRuntime;
    const o = overrides.sandboxRuntime;
    result.sandboxRuntime = {
      ...b,
      ...o,
      network: mergeOptional(b?.network, o.network),
      filesystem: mergeOptional(b?.filesystem, o.filesystem),
    };
  }

  if (overrides.justBash) {
    const b = base.justBash;
    const o = overrides.justBash;
    result.justBash = {
      ...b,
      ...o,
      network: mergeOptional(b?.network, o.network),
      filesystem: mergeOptional(b?.filesystem, o.filesystem),
    };
  }

  return result;
}

/**
 * Ref: https://github.com/qw457812/claude-code-sourcemap/blob/a8a678cb6244e6770e1e421767ff0987a1d95549/restored-src/src/utils/sandbox/sandbox-adapter.ts#L416-L445
 *
 * Detect if cwd is a git worktree and resolve the main repo path.
 * In a worktree, .git is a file (not a directory) containing "gitdir: ...".
 * If .git is a directory, readFileSync throws and we return null.
 */
function detectWorktreeMainRepoPath(cwd: string): string | null {
  const gitPath = join(cwd, ".git");
  if (!existsSync(gitPath)) {
    return null;
  }

  try {
    const gitContent = readFileSync(gitPath, "utf-8");
    const gitdirMatch = gitContent.match(/^gitdir:\s*(.+)$/m);
    if (!gitdirMatch?.[1]) {
      return null;
    }

    // gitdir may be relative (rare, but git accepts it) — resolve against cwd
    const gitdir = resolve(cwd, gitdirMatch[1].trim());
    // gitdir format: /path/to/main/repo/.git/worktrees/worktree-name
    // Match the /.git/worktrees/ segment specifically — indexOf('.git') alone
    // would false-match paths like /home/user/.github-projects/...
    const marker = `${sep}.git${sep}worktrees${sep}`;
    const markerIndex = gitdir.lastIndexOf(marker);
    if (markerIndex <= 0) {
      return null;
    }

    return gitdir.slice(0, markerIndex);
  } catch {
    // Not in a worktree, .git is a directory, or can't read .git file
    return null;
  }
}

function addBackendWritePath<T extends { filesystem?: { allowWrite?: string[] } }>(
  block: T | undefined,
  path: string,
): T | undefined {
  if (!block) return block;
  const allowWrite = block.filesystem?.allowWrite ?? [];
  if (allowWrite.includes(path)) return block;
  return { ...block, filesystem: { ...block.filesystem, allowWrite: [...allowWrite, path] } };
}

function withWorktreeMainRepoGitWriteAccess(config: SandboxConfig, cwd: string): SandboxConfig {
  const worktreeMainRepoPath = detectWorktreeMainRepoPath(cwd);
  if (!worktreeMainRepoPath || worktreeMainRepoPath === cwd) {
    return config;
  }

  // Git operations in a worktree need write access to the main repo's .git
  // directory for index.lock etc. Inject into both backends' allowWrite so that
  // whichever is active (and even if git runs sandboxed rather than as a just-bash
  // host process) keeps working.
  const gitPath = join(worktreeMainRepoPath, ".git");
  return {
    ...config,
    sandboxRuntime: addBackendWritePath(config.sandboxRuntime, gitPath),
    justBash: addBackendWritePath(config.justBash, gitPath),
  };
}

function isTermux(): boolean {
  return (
    (process.platform as string) === "android" ||
    process.env.PREFIX?.includes("/com.termux/") === true
  );
}

function createSandboxedBashOps(): BashOperations {
  return {
    async exec(command, cwd, { onData, signal, timeout, env }) {
      if (!existsSync(cwd)) {
        throw new Error(`Working directory does not exist: ${cwd}`);
      }

      const wrappedCommand = await SandboxManager.wrapWithSandbox(command);

      return new Promise((resolve, reject) => {
        const child = spawn("bash", ["-c", wrappedCommand], {
          cwd,
          detached: true,
          env,
          stdio: ["ignore", "pipe", "pipe"],
        });

        let timedOut = false;
        let timeoutHandle: NodeJS.Timeout | undefined;

        if (timeout !== undefined && timeout > 0) {
          timeoutHandle = setTimeout(() => {
            timedOut = true;
            if (child.pid) {
              try {
                process.kill(-child.pid, "SIGKILL");
              } catch {
                child.kill("SIGKILL");
              }
            }
          }, timeout * 1000);
        }

        child.stdout?.on("data", onData);
        child.stderr?.on("data", onData);

        child.on("error", (err) => {
          if (timeoutHandle) clearTimeout(timeoutHandle);
          reject(err);
        });

        const onAbort = () => {
          if (child.pid) {
            try {
              process.kill(-child.pid, "SIGKILL");
            } catch {
              child.kill("SIGKILL");
            }
          }
        };

        signal?.addEventListener("abort", onAbort, { once: true });

        child.on("close", (code) => {
          if (timeoutHandle) clearTimeout(timeoutHandle);
          signal?.removeEventListener("abort", onAbort);

          if (signal?.aborted) {
            reject(new Error("aborted"));
          } else if (timedOut) {
            reject(new Error(`timeout:${timeout}`));
          } else {
            resolve({ exitCode: code });
          }
        });
      });
    },
  };
}

// Track allowed domains for this session (user approved)
const sessionAllowedDomains = new Set<string>();

// Create the ask callback that prompts user for network permission
function createAskCallback(pi: ExtensionAPI, ctx: ExtensionContext): SandboxAskCallback {
  return async ({ host, port }) => {
    const target = port ? `${host}:${port}` : host;

    // Check if already approved this session
    if (sessionAllowedDomains.has(host) || sessionAllowedDomains.has(target)) {
      return true;
    }

    if (!ctx.hasUI) {
      return false;
    }

    // Known issues:
    // 1. Pending approvals still consume wall-clock timeouts, including bash tool
    //    timeout and `curl --connect-timeout`.
    // 2. Without a request-scoped signal, the dialog can outlive the originating
    //    command.
    try {
      pi.events.emit("my:notification", {
        title: "Pi Sandbox Network Approval",
        body: `Allow connection to ${target}?`,
      });
      const allowed = await ctx.ui.confirm("Network Access", `Allow connection to ${target}?`);

      if (allowed) {
        sessionAllowedDomains.add(host);
        ctx.ui.notify(`Allowed: ${target}`, "info");
      } else {
        ctx.ui.notify(`Blocked: ${target}`, "warning");
      }

      return allowed;
    } catch {
      return false;
    }
  };
}

function justBashDisplayLines(justBash: JustBashBackendConfig | undefined): string[] {
  const network = justBash?.network;
  return [
    "Just Bash Network:",
    `  Allowed URL Prefixes: ${formatAllowedUrlPrefixes(network?.allowedUrlPrefixes)}`,
    `  Allowed Methods: ${network?.allowedMethods?.join(", ") || "(default GET, HEAD)"}`,
    `  Full Internet: ${network?.dangerouslyAllowFullInternetAccess === true ? "true" : "false"}`,
    `  Deny Private Ranges: ${network?.denyPrivateRanges === undefined ? "(just-bash default)" : String(network.denyPrivateRanges)}`,
    "",
    "Just Bash Filesystem:",
    `  Allow Write: ${justBash?.filesystem?.allowWrite?.join(", ") || "(just-bash defaults)"}`,
    "",
    "Just Bash WASM Runtimes (sandboxed in-process):",
    `  Python: ${justBash?.python === true ? "on (python3/python; CPython Emscripten WASM)" : "off"}`,
    `  JavaScript: ${
      justBash?.javascript
        ? typeof justBash.javascript === "object"
          ? "on (js-exec; QuickJS WASM + bootstrap)"
          : "on (js-exec; QuickJS WASM)"
        : "off"
    }`,
    "",
    `  Host Commands (unsandboxed; disables just-bash defense; env scrubbed): ${justBash?.hostCommands?.join(", ") || "(none)"}`,
  ];
}

function sandboxRuntimeDisplayLines(runtime: SandboxRuntimeBackendConfig | undefined): string[] {
  const network = runtime?.network;
  const filesystem = runtime?.filesystem;
  return [
    "Network:",
    `  Allowed: ${network?.allowedDomains?.join(", ") || "(none)"}`,
    `  Denied: ${network?.deniedDomains?.join(", ") || "(none)"}`,
    `  Session approved: ${Array.from(sessionAllowedDomains).join(", ") || "(none)"}`,
    "",
    "Filesystem:",
    `  Allow Read: ${filesystem?.allowRead?.join(", ") || "(none)"}`,
    `  Deny Read: ${filesystem?.denyRead?.join(", ") || "(none)"}`,
    `  Allow Write: ${filesystem?.allowWrite?.join(", ") || "(none)"}`,
    `  Deny Write: ${filesystem?.denyWrite?.join(", ") || "(none)"}`,
  ];
}

export default function (pi: ExtensionAPI) {
  pi.registerFlag("no-sandbox", {
    description: "Disable OS-level sandboxing for bash commands",
    type: "boolean",
    default: false,
  });

  const platform = process.platform;
  const localCwd = process.cwd();
  const localBash = createBashTool(localCwd);

  let sandboxEnabled = false;
  let sandboxInitialized = false;
  let activeBackend: Backend | null = null;

  async function getExcludedCommandMatch(command: string, cwd: string) {
    const config = withWorktreeMainRepoGitWriteAccess(loadConfig(cwd), cwd);
    const backend = resolveBackend(config);
    const patterns = effectiveExcludedCommands(config, backend);
    if (patterns.length === 0) return null;
    return matchExcludedCommand(command, cwd, patterns);
  }

  function updateSandboxStatus(ctx: ExtensionContext) {
    if (!ctx.hasUI) return;
    if (!sandboxEnabled) {
      ctx.ui.setStatus("sandbox", undefined);
      return;
    }
    const backend = activeBackend ?? resolveBackend(loadConfig(ctx.cwd));

    if (backend === "justBash") {
      const config = loadConfig(ctx.cwd).justBash;
      const network = config?.network;
      const networkCount = network?.dangerouslyAllowFullInternetAccess
        ? "∞"
        : String(
            Array.isArray(network?.allowedUrlPrefixes) ? network.allowedUrlPrefixes.length : 0,
          );
      const writeCount = String(config?.filesystem?.allowWrite?.length ?? 0);
      ctx.ui.setStatus("sandbox", ctx.ui.theme.fg("dim", `󰌾 ${networkCount}/${writeCount}`));
      return;
    }
    const config = SandboxManager.getConfig();
    const networkCount = config?.network?.allowedDomains?.length ?? 0;
    const writeCount = config?.filesystem?.allowWrite?.length ?? 0;
    ctx.ui.setStatus("sandbox", ctx.ui.theme.fg("dim", `󰌾 ${networkCount}/${writeCount}`));
  }

  async function initializeSandbox(
    ctx: ExtensionContext,
    {
      respectConfigEnabled = true,
    }: {
      respectConfigEnabled?: boolean;
    } = {},
  ): Promise<boolean> {
    const config = withWorktreeMainRepoGitWriteAccess(loadConfig(ctx.cwd), ctx.cwd);
    if (respectConfigEnabled && !config.enabled) {
      sandboxEnabled = false;
      sandboxInitialized = false;
      activeBackend = null;
      updateSandboxStatus(ctx);
      ctx.ui.notify("Sandbox disabled via config", "info");
      return false;
    }

    const backend = resolveBackend(config);

    try {
      if (hasExcludedCommands(config, backend)) {
        await initializeExcludedCommandMatcher();
      }

      if (backend === "justBash") {
        sandboxEnabled = true;
        sandboxInitialized = true;
        activeBackend = backend;
        updateSandboxStatus(ctx);
        return true;
      }

      if (platform !== "darwin" && platform !== "linux") {
        sandboxEnabled = false;
        sandboxInitialized = false;
        activeBackend = null;
        updateSandboxStatus(ctx);
        ctx.ui.notify(`Sandbox not supported on ${platform}`, "warning");
        return false;
      }

      // DEFAULT_CONFIG always provides sandboxRuntime.network/filesystem and deepMerge
      // preserves them, so both are present whenever the sandboxRuntime backend runs.
      const runtimeConfig = config.sandboxRuntime!;

      const askCallback = createAskCallback(pi, ctx);

      await SandboxManager.initialize(
        {
          network: runtimeConfig.network!,
          filesystem: runtimeConfig.filesystem!,
          ignoreViolations: runtimeConfig.ignoreViolations,
          enableWeakerNestedSandbox: runtimeConfig.enableWeakerNestedSandbox,
          enableWeakerNetworkIsolation: runtimeConfig.enableWeakerNetworkIsolation,
        },
        askCallback,
      );

      sandboxEnabled = true;
      sandboxInitialized = true;
      activeBackend = backend;
      updateSandboxStatus(ctx);
      return true;
    } catch (err) {
      sandboxEnabled = false;
      sandboxInitialized = false;
      activeBackend = null;
      updateSandboxStatus(ctx);
      ctx.ui.notify(
        `Sandbox initialization failed: ${err instanceof Error ? err.message : err}`,
        "error",
      );
      return false;
    }
  }

  pi.registerTool({
    ...localBash,
    label: "bash (sandboxed)",
    async execute(id, params, signal, onUpdate, ctx) {
      if (!sandboxEnabled || !sandboxInitialized) {
        return localBash.execute(id, params, signal, onUpdate);
      }

      const command = typeof params?.command === "string" ? params.command : "";
      const excludedMatch = await getExcludedCommandMatch(command, ctx.cwd);
      if (excludedMatch) {
        if (ctx.hasUI) {
          ctx.ui.notify(
            `Bypassing sandbox: matched excluded command "${excludedMatch.pattern}"`,
            "info",
          );
        }
        return localBash.execute(id, params, signal, onUpdate);
      }

      const config = withWorktreeMainRepoGitWriteAccess(loadConfig(ctx.cwd), ctx.cwd);
      const backend = resolveBackend(config);

      if (backend === "justBash") {
        const justBash = createBashTool(ctx.cwd, {
          operations: createJustBashOps(ctx.cwd, config.justBash),
        });
        return justBash.execute(id, params, signal, onUpdate);
      }

      const sandboxedBash = createBashTool(localCwd, {
        operations: createSandboxedBashOps(),
      });
      return sandboxedBash.execute(id, params, signal, onUpdate);
    },
  });

  pi.on("user_bash", async (event, ctx) => {
    if (!sandboxEnabled || !sandboxInitialized) return;

    const excludedMatch = await getExcludedCommandMatch(event.command, event.cwd);
    if (excludedMatch) {
      if (ctx.hasUI) {
        ctx.ui.notify(
          `Bypassing sandbox: matched excluded command "${excludedMatch.pattern}"`,
          "info",
        );
      }
      return { operations: createLocalBashOperations() };
    }

    const config = withWorktreeMainRepoGitWriteAccess(loadConfig(event.cwd), event.cwd);
    const backend = resolveBackend(config);

    if (backend === "justBash") {
      return {
        operations: createJustBashOps(event.cwd, config.justBash),
      };
    }

    return { operations: createSandboxedBashOps() };
  });

  pi.on("session_start", async (_event, ctx) => {
    const noSandbox = pi.getFlag("no-sandbox") as boolean;

    if (noSandbox) {
      sandboxEnabled = false;
      sandboxInitialized = false;
      activeBackend = null;
      updateSandboxStatus(ctx);
      ctx.ui.notify("Sandbox disabled via --no-sandbox", "warning");
      return;
    }

    if (await initializeSandbox(ctx)) {
      ctx.ui.notify("Sandbox initialized", "info");
    }
  });

  pi.on("session_shutdown", async () => {
    if (sandboxInitialized && activeBackend === "sandboxRuntime") {
      try {
        await SandboxManager.reset();
      } catch {
        // Ignore cleanup errors
      }
    }

    sandboxEnabled = false;
    sandboxInitialized = false;
    activeBackend = null;

    // Clear session state
    sessionAllowedDomains.clear();
  });

  pi.registerCommand("sandbox", {
    description: "Show sandbox configuration or toggle (/sandbox [on|off])",
    getArgumentCompletions(prefix: string) {
      const items = ["on", "off"]
        .filter((item) => item.startsWith(prefix.trimStart().toLowerCase()))
        .map((item) => ({ value: item, label: item }));
      return items.length > 0 ? items : null;
    },
    handler: async (args, ctx) => {
      const arg = args.trim().toLowerCase();

      if (arg === "on") {
        if (sandboxEnabled) {
          ctx.ui.notify("Sandbox is already enabled", "info");
          return;
        }
        if (sandboxInitialized) {
          sandboxEnabled = true;
          updateSandboxStatus(ctx);
          ctx.ui.notify("Sandbox enabled", "info");
          return;
        }
        if (await initializeSandbox(ctx, { respectConfigEnabled: false })) {
          ctx.ui.notify("Sandbox enabled", "info");
        }
        return;
      }

      if (arg === "off") {
        if (!sandboxEnabled) {
          ctx.ui.notify("Sandbox is already disabled", "info");
          return;
        }
        sandboxEnabled = false;
        updateSandboxStatus(ctx);
        ctx.ui.notify("Sandbox disabled", "warning");
        return;
      }

      // No args — show status
      if (!arg) {
        if (!sandboxEnabled) {
          ctx.ui.notify("Sandbox is disabled. Use `/sandbox on` to enable.", "info");
          return;
        }

        const config = loadConfig(ctx.cwd);
        const backend = activeBackend ?? resolveBackend(config);
        const effectivePatterns = effectiveExcludedCommands(config, backend);
        const lines = [
          "Sandbox: ENABLED",
          "",
          `Backend: ${backend}`,
          "",
          "Excluded Commands:",
          `  ${effectivePatterns.join(", ") || "(none)"}`,
          "",
          ...(backend === "justBash"
            ? justBashDisplayLines(config.justBash)
            : sandboxRuntimeDisplayLines(config.sandboxRuntime)),
        ];
        ctx.ui.notify(lines.join("\n"), "info");
        return;
      }

      ctx.ui.notify("Usage: /sandbox [on|off]", "error");
    },
  });
}
