/**
 * Conditionally disable the `mcp` proxy tool when no MCP servers need it.
 *
 * pi-mcp-adapter registers the `mcp` proxy tool when `disableProxyTool: true`
 * but no direct tools exist in cache (empty mcpServers or missing cache).
 * Since v2.12.0, the adapter can also reactivate `mcp` asynchronously after
 * initialization or metadata updates. This extension checks the merged MCP
 * config and disables `mcp` when every configured server has effective
 * `directTools: true` (i.e. no server relies on the proxy for tool access),
 * then enforces that decision after each adapter status update. Status
 * snapshots also prevent disabling the proxy when v2.27.0+ discovers servers
 * from Pi package manifests or runtime extension registrations.
 *
 * Uses getActiveTools() → Set → delete → Array.from pattern
 * to incrementally remove without re-enabling tools disabled by other extensions.
 *
 * Config precedence matches pi-mcp-adapter:
 *   ~/.config/mcp/mcp.json → <agentDir>/mcp.json → .mcp.json → .pi/mcp.json
 * Per-server `directTools` overrides the global `settings.directTools`.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

interface McpServerEntry {
  disabled?: boolean;
  directTools?: boolean | string[];
  [key: string]: unknown;
}

interface McpConfig {
  mcpServers?: Record<string, McpServerEntry>;
  imports?: string[];
  settings?: {
    directTools?: boolean | string[];
    disableProxyTool?: boolean;
    agentPluginPaths?: unknown;
    [key: string]: unknown;
  };
}

interface McpStatusSnapshot {
  version: 1;
  servers: Array<{ name: string }>;
}

const MCP_STATUS_EVENT = "pi-mcp-adapter/status/v1";

const CONFIG_PATHS = [
  join(homedir(), ".config", "mcp", "mcp.json"),
  ".mcp.json",
  join(CONFIG_DIR_NAME, "mcp.json"),
];

function readJsonConfig(path: string): McpConfig | null {
  try {
    if (!existsSync(path)) return null;
    return JSON.parse(readFileSync(path, "utf-8"));
  } catch {
    return null;
  }
}

function loadMergedConfig(cwd: string): McpConfig {
  const agentDir = getAgentDir();
  const paths = [
    CONFIG_PATHS[0], // ~/.config/mcp/mcp.json
    join(agentDir, "mcp.json"), // <agentDir>/mcp.json
    ...CONFIG_PATHS.slice(1), // .mcp.json, .pi/mcp.json
  ];

  let merged: McpConfig = {};
  for (const p of paths) {
    const cfg = readJsonConfig(resolve(cwd, p));
    if (!cfg) continue;
    merged = {
      mcpServers: { ...merged.mcpServers, ...cfg.mcpServers },
      imports: [...(merged.imports ?? []), ...(cfg.imports ?? [])],
      settings: { ...merged.settings, ...cfg.settings },
    };
  }
  return merged;
}

/** An enabled server needs the proxy when its effective directTools is not `true`. */
function serverNeedsProxy(entry: McpServerEntry, globalDirect?: boolean | string[]): boolean {
  if (entry.disabled === true) return false;
  if (entry.directTools === undefined) {
    if (globalDirect === undefined) return true;
    if (globalDirect === true) return false;
    if (Array.isArray(globalDirect)) return true;
    return true;
  }
  if (entry.directTools === true) return false;
  if (Array.isArray(entry.directTools)) return true;
  return true;
}

function getStatusServerNames(value: unknown): string[] | null {
  if (!value || typeof value !== "object") return null;
  const { version, servers } = value as Partial<McpStatusSnapshot>;
  if (version !== 1 || !Array.isArray(servers)) return null;

  const names: string[] = [];
  for (const server of servers) {
    if (!server || typeof server !== "object" || typeof server.name !== "string") return null;
    names.push(server.name);
  }
  return names;
}

export default function (pi: ExtensionAPI) {
  let configAllowsDisable = false;
  let configuredServerNames = new Set<string>();
  let observedServerNames: string[] | null = null;
  let shouldDisable = false;

  const updateDecision = () => {
    shouldDisable =
      configAllowsDisable &&
      (observedServerNames === null ||
        observedServerNames.every(
          // Package servers always use <sanitized-package>__<sanitized-server>.
          // Treat even a same-named local override conservatively because the
          // adapter may inherit proxy-related fields from the package entry.
          (name) => !name.includes("__") && configuredServerNames.has(name),
        ));
  };

  const enforceDisabled = () => {
    if (!shouldDisable || !pi.getAllTools().some((t) => t.name === "mcp")) return;

    const active = new Set(pi.getActiveTools());
    if (!active.delete("mcp")) return;
    pi.setActiveTools(Array.from(active));
  };

  // pi-mcp-adapter emits this after initialization and metadata changes. Its
  // syncToolSurface() runs before the status event, so remove any `mcp` tool
  // that v2.12.0+ just reactivated. Unknown server names are package-manifest
  // or runtime registrations that this extension must conservatively leave on
  // the proxy surface.
  const offMcpStatus = pi.events.on(MCP_STATUS_EVENT, (snapshot) => {
    const serverNames = getStatusServerNames(snapshot);
    if (serverNames) observedServerNames = serverNames;
    updateDecision();
    enforceDisabled();
  });

  pi.on("session_start", async (_event, ctx) => {
    const config = loadMergedConfig(ctx.cwd);
    const servers = config.mcpServers ?? {};
    const globalDirect = config.settings?.directTools;
    const agentPluginPaths = config.settings?.agentPluginPaths;
    const hasAgentPlugins = Array.isArray(agentPluginPaths) && agentPluginPaths.length > 0;

    configuredServerNames = new Set(Object.keys(servers));
    configAllowsDisable =
      config.settings?.disableProxyTool === true &&
      // Imported host configs may contain servers that rely on the proxy.
      (config.imports?.length ?? 0) === 0 &&
      // Agent Plugins add servers outside these config files.
      !hasAgentPlugins &&
      (configuredServerNames.size === 0 ||
        !Object.values(servers).some((server) => serverNeedsProxy(server, globalDirect)));

    updateDecision();
    enforceDisabled();
  });

  pi.on("session_shutdown", () => {
    configAllowsDisable = false;
    configuredServerNames.clear();
    observedServerNames = null;
    shouldDisable = false;
    offMcpStatus();
  });
}
