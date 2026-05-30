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
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const IS_TERMUX = Boolean(process.env.TERMUX_VERSION);
const SLES_SOURCE_MODULE = "module-sles-source";

async function ensurePulseAudio(ctx: ExtensionContext): Promise<void> {
  if (!IS_TERMUX || !ctx.hasUI) return;

  try {
    await execFileAsync("pulseaudio", ["--check"], { timeout: 3000 });
  } catch (e: unknown) {
    const error = e as ExecFileException;
    if (error.code === 1) {
      try {
        await execFileAsync("pulseaudio", ["--start", "--exit-idle-time=-1"], { timeout: 5000 });
      } catch (startError: unknown) {
        const startExecError = startError as ExecFileException;
        ctx.ui.notify(`[listen] Failed to start PulseAudio: ${startExecError.message}`, "error");
        return;
      }
    } else if (error.code === "ENOENT") {
      ctx.ui.notify(
        "[listen] pulseaudio not found, run `pkg install pulseaudio` to enable mic for pi-listen.",
        "error",
      );
      return;
    } else {
      ctx.ui.notify(`[listen] Unexpected pulseaudio, check failure: ${error.message}`, "error");
      return;
    }
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
    if (error.code === "ENOENT") {
      ctx.ui.notify(
        "[listen] pactl not found, run `pkg install pulseaudio` to enable mic for pi-listen.",
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
