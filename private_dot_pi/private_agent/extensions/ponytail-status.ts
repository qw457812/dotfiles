/**
 * Show the active Ponytail mode in the footer.
 *
 * Reads ponytail's `ponytail-mode` session entries (from its /ponytail commands)
 * with ponytail's own default resolution (env > config.json > full). `off` hides the status.
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

// Mirrors ponytail's default-mode resolution (env > config.json > full):
// https://github.com/DietrichGebert/ponytail/blob/dedc97c/hooks/ponytail-config.js
function getDefaultMode(): Mode {
  const env = process.env.PONYTAIL_DEFAULT_MODE?.toLowerCase();
  if (env && VALID.includes(env)) return env as Mode;

  try {
    const cfg = JSON.parse(readFileSync(getConfigPath(), "utf8")) as { defaultMode?: string };
    const m = cfg.defaultMode?.toLowerCase();
    if (m && VALID.includes(m)) return m as Mode;
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

  const applyStatus = (ctx: ExtensionContext, mode: Mode): void => {
    ctx.ui.setStatus(
      STATUS_KEY,
      mode === "off" ? undefined : ctx.ui.theme.fg("accent", `ponytail-${mode}`),
    );
  };

  const readEntries = (ctx: ExtensionContext): readonly SessionEntry[] =>
    (ctx.sessionManager?.getBranch?.() ??
      ctx.sessionManager?.getEntries?.() ??
      []) as readonly SessionEntry[];

  pi.on("session_start", async (_event, ctx) => {
    configuredDefaultMode = getDefaultMode();
    applyStatus(ctx, resolveSessionMode(readEntries(ctx), configuredDefaultMode));
  });

  pi.on("before_agent_start", async (_event, ctx) => {
    applyStatus(ctx, resolveSessionMode(readEntries(ctx), configuredDefaultMode));
  });
}
