/**
 * Conditionally disable the `mcp` proxy tool when no MCP servers need it.
 *
 * pi-mcp-adapter registers the `mcp` proxy tool when `disableProxyTool: true`
 * but no direct tools exist in cache (empty mcpServers or missing cache).
 * This extension checks the merged MCP config and disables `mcp` when every
 * configured server has effective `directTools: true` (i.e. no server
 * relies on the proxy for tool access).
 *
 * Uses getActiveTools() → Set → delete → Array.from pattern
 * to incrementally remove without re-enabling tools disabled by other extensions.
 *
 * Config precedence matches pi-mcp-adapter:
 *   ~/.config/mcp/mcp.json → <agentDir>/mcp.json → .mcp.json → .pi/mcp.json
 * Per-server `directTools` overrides the global `settings.directTools`.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
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
    [key: string]: unknown;
  };
}

const CONFIG_PATHS = [join(homedir(), ".config", "mcp", "mcp.json"), ".mcp.json", ".pi/mcp.json"];

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
  pi.on("session_start", async (_event, ctx) => {
    if (!pi.getAllTools().some((t) => t.name === "mcp")) return;

    const config = loadMergedConfig(ctx.cwd);

    // Only act when the user opted into disableProxyTool
    if (config.settings?.disableProxyTool !== true) return;

    // If imports are present, servers may come from external host configs
    // that we can't see — conservatively keep the proxy
    if (config.imports && config.imports.length > 0) return;

    const servers = config.mcpServers ?? {};
    const globalDirect = config.settings?.directTools;

    const shouldDisable =
      Object.keys(servers).length === 0 ||
      !Object.values(servers).some((s) => serverNeedsProxy(s, globalDirect));
    if (!shouldDisable) return;

    const active = new Set(pi.getActiveTools());
    active.delete("mcp");
    pi.setActiveTools(Array.from(active));
  });
}
