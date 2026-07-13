import type { JavaScriptConfig, NetworkConfig } from "just-bash";

export interface JustBashFilesystemConfig {
  /** Write roots plumbed into just-bash's virtual filesystem (MountableFs mounts). */
  allowWrite?: string[];
  /** Read roots whose contents and direct metadata access are denied. */
  denyRead?: string[];
  /** Read roots that override denyRead for content and direct metadata access. */
  allowRead?: string[];
}

export interface JustBashConfig {
  /** Passed through verbatim to just-bash as trusted local NetworkConfig. */
  network?: NetworkConfig;
  /**
   * Filesystem policy for the just-bash sandbox backend. `allowWrite` is
   * plumbed into MountableFs as writable roots; `denyRead` / `allowRead` deny
   * content reads and direct metadata access. Existing configured read roots
   * are matched by both their normalized path and realpath alias. They
   * intentionally do not promise complete existence hiding, matching
   * sandbox-runtime's practical semantics. The rest of the writable defaults —
   * /dev devices, TMPDIR, ~/.npm/_logs, etc. — are supplied by
   * defaultAndConfiguredWriteRoots() in the filesystem module.
   */
  filesystem?: JustBashFilesystemConfig;
  /**
   * Enable the sandboxed `python3`/`python` commands (CPython 3.13 compiled to
   * WASM via Emscripten). Runs ENTIRELY inside just-bash's WASM sandbox: file
   * access goes through the same MountableFs (host read-only outside the
   * configured write roots) and network through the configured NetworkConfig.
   * No host process is spawned. Introduces a CPython WASM runtime security
   * surface, hence opt-in; see just-bash's THREAT_MODEL.md §4.7.
   *
   * Precedence: if a python command name is ALSO in `hostCommands`, the host
   * process wins (customCommands are registered last in just-bash's Bash
   * constructor), so the WASM runtime only takes effect for names NOT claimed
   * by hostCommands.
   */
  python?: boolean;
  /**
   * Enable the sandboxed `js-exec` command (QuickJS WASM) for JavaScript /
   * TypeScript. Runs inside just-bash's WASM sandbox under the same FS/network
   * policy as `python`. A `node` *stub* is registered alongside it that prints
   * a pointer to `js-exec`; if `node` is ALSO in `hostCommands`, the host
   * process wins (customCommands registered last), so the stub is dormant.
   *
   * Note: QuickJS js-exec is NOT a Node.js toolchain — no `node_modules`
   * resolution, no native addons, no `npm install`. For project build tools
   * (tsc/vitest/npm scripts) keep the host command in `hostCommands`.
   */
  javascript?: boolean | JavaScriptConfig;
  /**
   * Escape hatch for commands that just-bash does not implement (for example `git`).
   * These run as REAL HOST PROCESSES via spawn(): they bypass just-bash's
   * filesystem and network restrictions entirely. Any listed command grants
   * full unsandboxed code execution on the host (e.g. `node -e` or `git` with
   * hooks/config/`ext::` transports), so treat the list as a deliberate escape
   * hatch, not a convenience. The child env is scrubbed (proxy and
   * secret-shaped vars removed) and PATH is forced to the host PATH.
   * NOTE: enabling any host command also disables just-bash
   * `defenseInDepth` for that Bash instance (currently required to work
   * around a just-bash bug where command-prefix assignments trigger a DiD
   * violation). Prefer a short explicit allow-list.
   */
  hostCommands?: string[];
}

export function formatAllowedUrlPrefixes(
  entries: NetworkConfig["allowedUrlPrefixes"] | undefined,
): string {
  if (!Array.isArray(entries) || entries.length === 0) return "(none)";
  return entries
    .map((entry) => {
      if (typeof entry === "string") return entry;
      return entry.url;
    })
    .join(", ");
}
