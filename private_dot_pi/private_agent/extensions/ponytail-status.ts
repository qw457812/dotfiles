/**
 * Compact override of ponytail's status-bar text (unconfigurable upstream,
 * introduced in DietrichGebert/ponytail@947f2ff). Defers the write with
 * setTimeout(0) so it lands after ponytail's own handlers regardless of
 * load order. `off` hides the status.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const STATUS_KEY = "ponytail";
const DEFAULT_MODE = "full";

const VALID_MODES = ["off", "lite", "full", "ultra", "review"] as const;
const VALID = VALID_MODES as readonly string[];
type Mode = (typeof VALID_MODES)[number];

const RUNTIME_MODES = ["off", "lite", "full", "ultra"] as const;
const RUNTIME = RUNTIME_MODES as readonly string[];

type SessionEntry = { type?: string; customType?: string; data?: { mode?: unknown } };

// Mirrors ponytail's config-path resolution (XDG_CONFIG_HOME > APPDATA on win32 > ~/.config):
// https://github.com/DietrichGebert/ponytail/blob/dedc97c/hooks/ponytail-config.js
function getConfigPath(): string {
  if (process.env.XDG_CONFIG_HOME)
    return join(process.env.XDG_CONFIG_HOME, "ponytail", "config.json");
  if (process.platform === "win32") {
    return join(
      process.env.APPDATA || join(homedir(), "AppData", "Roaming"),
      "ponytail",
      "config.json",
    );
  }
  return join(homedir(), ".config", "ponytail", "config.json");
}

// Mirrors ponytail's default-mode resolution (env > config.json > full); review
// is excluded as a default (#377):
// https://github.com/DietrichGebert/ponytail/blob/14a0d79/hooks/ponytail-config.js
function getDefaultMode(): Mode {
  const env = process.env.PONYTAIL_DEFAULT_MODE?.toLowerCase();
  if (env && RUNTIME.includes(env)) return env as Mode;

  try {
    const cfg = JSON.parse(readFileSync(getConfigPath(), "utf8")) as { defaultMode?: string };
    const m = cfg.defaultMode?.toLowerCase();
    if (m && RUNTIME.includes(m)) return m as Mode;
  } catch {
    // no/invalid config file — fall through to default
  }
  return DEFAULT_MODE;
}

// Mirrors ponytail's resolveSessionMode; the entry key is written by its
// /ponytail command handler (pi.appendEntry("ponytail-mode", { mode })):
// https://github.com/DietrichGebert/ponytail/blob/dedc97c/pi-extension/index.js
function resolveSessionMode(entries: readonly SessionEntry[], fallbackMode: Mode): Mode {
  for (let i = entries.length - 1; i >= 0; i -= 1) {
    const entry = entries[i];
    if (entry?.type !== "custom" || entry?.customType !== "ponytail-mode") continue;
    const m = String(entry?.data?.mode ?? "")
      .trim()
      .toLowerCase();
    if (VALID.includes(m)) return m as Mode;
  }
  return fallbackMode;
}

export default function (pi: ExtensionAPI): void {
  let configuredDefaultMode = getDefaultMode();

  const syncStatus = (ctx: ExtensionContext): void => {
    const entries = (ctx.sessionManager?.getBranch?.() ??
      ctx.sessionManager?.getEntries?.() ??
      []) as readonly SessionEntry[];
    const mode = resolveSessionMode(entries, configuredDefaultMode);
    const status = mode === "off" ? undefined : ctx.ui.theme.fg("accent", `󱖿 ${mode}`);
    setTimeout(() => ctx.ui.setStatus(STATUS_KEY, status), 0);
  };

  pi.on("session_start", async (_event, ctx) => {
    configuredDefaultMode = getDefaultMode();
    syncStatus(ctx);
  });

  pi.on("agent_start", async (_event, ctx) => syncStatus(ctx));
  pi.on("agent_end", async (_event, ctx) => syncStatus(ctx));
}
