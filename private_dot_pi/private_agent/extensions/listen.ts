/**
 * https://github.com/codexstar69/pi-listen
 * https://github.com/qw457812/pi-listen
 *
 * Ensures PulseAudio microphone module is running for pi-listen on Termux.
 *
 * On Termux (Android), SoX `rec` cannot access the microphone directly.
 * This extension starts PulseAudio and loads `module-sles-source` so `rec`
 * can capture audio through PulseAudio.
 *
 * Only activates on Termux (Android). No-op on other platforms.
 *
 * Prerequisites:
 * - `pi install npm:@codexstar/pi-listen` or `pi install git:github.com/qw457812/pi-listen`
 * - `pkg install pulseaudio sox` (Termux) or `brew install sox` (macOS)
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { execFile, type ExecFileException } from "node:child_process";
import { lstat, readdir, realpath, unlink, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const IS_TERMUX = Boolean(process.env.TERMUX_VERSION);
const SLES_SOURCE_MODULE = "module-sles-source";
const PULSE_AUDIO_START_ARGS = ["--start", "--exit-idle-time=-1"];
const NO_AUTOSPAWN_CLIENT_CONFIG = path.join(tmpdir(), "pi-listen-pulse-client.conf");

function hasErrorCode(error: unknown, code: string | number): boolean {
  return typeof error === "object" && error !== null && "code" in error && error.code === code;
}

function isMissingCommand(error: unknown): boolean {
  return hasErrorCode(error, "ENOENT");
}

function missingCommandName(error: unknown): string {
  if (
    typeof error === "object" &&
    error !== null &&
    "path" in error &&
    typeof error.path === "string"
  ) {
    return error.path;
  }
  return "pulseaudio";
}

function formatError(error: unknown): string {
  if (!(error instanceof Error)) return String(error);

  const execError = error as ExecFileException;
  return (execError.stderr || execError.message).trim();
}

async function canConnectToPulseAudioWithoutAutospawn(): Promise<boolean> {
  await writeFile(NO_AUTOSPAWN_CLIENT_CONFIG, "autospawn = no\n");

  try {
    await execFileAsync("pactl", ["info"], {
      env: { ...process.env, PULSE_CLIENTCONFIG: NO_AUTOSPAWN_CLIENT_CONFIG },
      timeout: 3000,
    });
    return true;
  } catch (error) {
    if (hasErrorCode(error, 1)) return false;
    throw error;
  }
}

async function isPulseAudioRunning(): Promise<boolean> {
  try {
    await execFileAsync("pulseaudio", ["--check"], { timeout: 3000 });
    return true;
  } catch (error) {
    if (hasErrorCode(error, 1)) return false;
    throw error;
  }
}

async function addPulseRuntimeDirsFromConfig(configDir: string, dirs: Set<string>): Promise<void> {
  let entries;
  try {
    entries = await readdir(configDir, { withFileTypes: true });
  } catch (error) {
    if (hasErrorCode(error, "ENOENT")) return;
    throw error;
  }

  for (const entry of entries) {
    if (!entry.name.endsWith("-runtime")) continue;

    const candidate = path.join(configDir, entry.name);
    try {
      dirs.add(await realpath(candidate));
    } catch (error) {
      if (hasErrorCode(error, "ENOENT")) continue;
      throw error;
    }
  }
}

async function pulseRuntimeDirs(): Promise<string[]> {
  const dirs = new Set<string>();

  if (process.env.PULSE_RUNTIME_PATH) dirs.add(process.env.PULSE_RUNTIME_PATH);
  if (process.env.XDG_RUNTIME_DIR) dirs.add(path.join(process.env.XDG_RUNTIME_DIR, "pulse"));

  const xdgConfigHome = process.env.XDG_CONFIG_HOME || path.join(homedir(), ".config");
  await addPulseRuntimeDirsFromConfig(path.join(xdgConfigHome, "pulse"), dirs);
  await addPulseRuntimeDirsFromConfig(path.join(homedir(), ".pulse"), dirs);

  return [...dirs];
}

async function unlinkIfSocket(filePath: string): Promise<void> {
  let stat;
  try {
    stat = await lstat(filePath);
  } catch (error) {
    if (hasErrorCode(error, "ENOENT")) return;
    throw error;
  }

  if (!stat.isSocket()) return;

  try {
    await unlink(filePath);
  } catch (error) {
    if (hasErrorCode(error, "ENOENT")) return;
    throw error;
  }
}

async function clearStalePulseRuntimeFiles(): Promise<void> {
  for (const dir of await pulseRuntimeDirs()) {
    await unlinkIfSocket(path.join(dir, "native"));
  }
}

async function startPulseAudio(): Promise<void> {
  try {
    await execFileAsync("pulseaudio", PULSE_AUDIO_START_ARGS, { timeout: 5000 });
    return;
  } catch (error) {
    if (!hasErrorCode(error, 1)) throw error;
    if (await canConnectToPulseAudioWithoutAutospawn()) return;
  }

  // Termux can leave a stale PulseAudio socket after Android kills the daemon.
  // Only retry cleanup for PulseAudio's expected startup failure exit code.
  await clearStalePulseRuntimeFiles();
  await execFileAsync("pulseaudio", PULSE_AUDIO_START_ARGS, { timeout: 5000 });
}

async function ensurePulseAudio(ctx: ExtensionContext): Promise<void> {
  if (!IS_TERMUX || !ctx.hasUI) return;

  try {
    if (!(await isPulseAudioRunning())) await startPulseAudio();
  } catch (e: unknown) {
    const error = e as ExecFileException;
    if (isMissingCommand(error)) {
      ctx.ui.notify(
        `[listen] ${missingCommandName(error)} not found, run \`pkg install pulseaudio\` to enable mic for pi-listen.`,
        "error",
      );
      return;
    }
    ctx.ui.notify(`[listen] Failed to start PulseAudio: ${formatError(error)}`, "error");
    return;
  }

  try {
    const { stdout } = await execFileAsync("pactl", ["list", "short", "modules"], {
      timeout: 3000,
    });
    const moduleLoaded = stdout
      .split("\n")
      .some((line) => line.split("\t")[1] === SLES_SOURCE_MODULE);
    if (!moduleLoaded) {
      await execFileAsync("pactl", ["load-module", SLES_SOURCE_MODULE], { timeout: 3000 });
    }
  } catch (e: unknown) {
    const error = e as ExecFileException;
    if (isMissingCommand(error)) {
      ctx.ui.notify(
        `[listen] ${missingCommandName(error)} not found, run \`pkg install pulseaudio\` to enable mic for pi-listen.`,
        "error",
      );
      return;
    }
    ctx.ui.notify(
      `[listen] Failed to ensure module-sles-source is loaded: ${error.message}`,
      "error",
    );
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    await ensurePulseAudio(ctx);
  });
}
