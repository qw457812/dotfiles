/**
 * Conditionally disable the `mcp` proxy tool when no MCP servers need it.
 *
 * pi-mcp-adapter registers the `mcp` proxy tool when `disableProxyTool: true`
 * but no direct tools exist in cache (empty mcpServers or missing cache).
 * Since v2.12.0, the adapter can also reactivate `mcp` asynchronously after
 * initialization or metadata updates. This extension checks the merged MCP
 * config and disables `mcp` when every configured server has effective
 * `directTools: true` (i.e. no server relies on the proxy for tool access),
 * then enforces that decision after each adapter status update.
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

/** A server needs the proxy when its effective directTools is not `true`. */
function serverNeedsProxy(entry: McpServerEntry, globalDirect?: boolean | string[]): boolean {
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

export default function (pi: ExtensionAPI) {
  let shouldDisable = false;

  const enforceDisabled = () => {
    if (!shouldDisable || !pi.getAllTools().some((t) => t.name === "mcp")) return;

    const active = new Set(pi.getActiveTools());
    if (!active.delete("mcp")) return;
    pi.setActiveTools(Array.from(active));
  };

  // pi-mcp-adapter emits this after initialization and metadata changes. Its
  // syncToolSurface() runs before the status event, so remove any `mcp` tool
  // that v2.12.0+ just reactivated.
  const offMcpStatus = pi.events.on(MCP_STATUS_EVENT, enforceDisabled);

  pi.on("session_start", async (_event, ctx) => {
    const config = loadMergedConfig(ctx.cwd);
    const servers = config.mcpServers ?? {};
    const globalDirect = config.settings?.directTools;
    const agentPluginPaths = config.settings?.agentPluginPaths;
    const hasAgentPlugins = Array.isArray(agentPluginPaths) && agentPluginPaths.length > 0;

    shouldDisable =
      config.settings?.disableProxyTool === true &&
      // Imported host configs may contain servers that rely on the proxy.
      (config.imports?.length ?? 0) === 0 &&
      // Agent Plugins add servers outside these config files
      !hasAgentPlugins &&
      (Object.keys(servers).length === 0 ||
        !Object.values(servers).some((server) => serverNeedsProxy(server, globalDirect)));

    enforceDisabled();
  });

  pi.on("session_shutdown", () => {
    shouldDisable = false;
    offMcpStatus();
  });
}
