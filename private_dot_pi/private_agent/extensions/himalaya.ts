import {
  isToolCallEventType,
  type ExtensionAPI,
  type ExtensionUIContext,
} from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const IS_TERMUX = Boolean(process.env.TERMUX_VERSION);
const HOME = homedir();
const PASS_STORE = process.env.PASSWORD_STORE_DIR || join(HOME, ".password-store");

// The `pass show <entry>` a configured secret command runs.
const PASS_SHOW_RE = /\bpass[\s"',]+show[\s"',]+([^\s"'`,;|&$)]+)/g;

export function passEntries(text: string): string[] {
  const uncommented = text.replace(/(^|\s)#.*$/gm, "$1");
  return [...uncommented.matchAll(PASS_SHOW_RE)].map((match) => match[1]);
}

// Config is authoritative: pass entries may be named anything.
function discoverEntries(): string[] {
  // TODO: himalaya master ignores HIMALAYA_CONFIG and deep-merges every default
  // path; scan env paths plus XDG, ~/.config and ~/.himalayarc instead.
  const configured = process.env.HIMALAYA_CONFIG?.split(":").filter(Boolean) ?? [];
  const files = configured.length
    ? configured
    : [
        join(process.env.XDG_CONFIG_HOME ?? join(HOME, ".config"), "himalaya/config.toml"),
        join(HOME, ".himalayarc"),
      ];

  const entries = new Set<string>();
  for (const file of files) {
    let text: string;
    try {
      text = readFileSync(file, "utf8");
    } catch {
      continue;
    }
    for (const entry of passEntries(text)) {
      // Skip flags and stale names the loose match can catch.
      if (existsSync(join(PASS_STORE, `${entry}.gpg`))) entries.add(entry);
    }
  }
  return [...entries].sort();
}

// --batch fails fast on a cold cache instead of invoking a pinentry we can't serve.
function probeCache(entry: string, signal?: AbortSignal): Promise<boolean> {
  return new Promise((resolve) => {
    if (signal?.aborted) {
      resolve(false);
      return;
    }
    const child = spawn("gpg", ["--batch", "--decrypt", join(PASS_STORE, `${entry}.gpg`)], {
      stdio: "ignore",
      signal,
    });
    child.once("error", () => resolve(false));
    child.once("close", (code) => resolve(code === 0));
  });
}

function decryptEntry(entry: string, passphrase: string): Promise<{ ok: boolean; error?: string }> {
  return new Promise((resolve) => {
    const child = spawn(
      "gpg",
      [
        "--batch",
        "--yes",
        "--pinentry-mode",
        "loopback",
        "--passphrase-fd",
        "0",
        "--decrypt",
        join(PASS_STORE, `${entry}.gpg`),
      ],
      { stdio: ["pipe", "ignore", "pipe"] },
    );

    let stderr = "";
    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });
    child.once("error", (err) => resolve({ ok: false, error: err.message }));
    child.once("close", (code) => {
      resolve(
        code === 0
          ? { ok: true }
          : { ok: false, error: stderr.trim() || `gpg exited with code ${code}` },
      );
    });

    child.stdin.write(`${passphrase}\n`);
    child.stdin.end();
  });
}

async function unlockPassEntries(
  entry: string,
  ui: ExtensionUIContext,
  signal?: AbortSignal,
): Promise<boolean> {
  const passphrase = await ui.input(
    "Himalaya GPG passphrase",
    "passphrase for the password-store GPG key",
    { signal },
  );
  if (!passphrase) {
    ui.notify("Himalaya unlock cancelled.", "info");
    return false;
  }

  if (signal?.aborted) return false;
  const result = await decryptEntry(entry, passphrase);
  if (!result.ok) {
    ui.notify(`Himalaya unlock failed for ${entry}: ${result.error}`, "error");
    return false;
  }

  ui.notify("Himalaya unlocked. GPG passphrase is cached.", "info");
  return true;
}

let unlockInFlight: Promise<boolean> | undefined;

async function ensureUnlocked(ui: ExtensionUIContext, signal?: AbortSignal): Promise<void> {
  if (signal?.aborted) return;
  const entries = discoverEntries();
  if (entries.length === 0) return;

  // One entry seeds the key shared by all accounts.
  const entry = entries[0];
  if (await probeCache(entry, signal)) return;
  if (signal?.aborted) return;

  if (!unlockInFlight) {
    unlockInFlight = unlockPassEntries(entry, ui, signal).finally(() => {
      unlockInFlight = undefined;
    });
  }
  await unlockInFlight;
}

export default function himalayaExtension(pi: ExtensionAPI): void {
  if (!IS_TERMUX) return;

  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;
    if (typeof event.input.command !== "string") return;
    if (!/\bhimalaya\b/.test(event.input.command)) return;
    if (!ctx.hasUI) return;

    await ensureUnlocked(ctx.ui, ctx.signal);
  });
}
