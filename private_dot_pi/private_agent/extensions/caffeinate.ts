// Copied from: https://github.com/georgebashi/pi-caffeinate/blob/7b29059a66fa341768aa3d0087cabf6d26e3e3a7/index.ts

/**
 * pi-caffeinate — Keep the machine awake while the agent is working.
 *
 * Works on macOS, Linux, Termux, and Windows:
 *
 * macOS:   Spawns `caffeinate -i` which creates a keep-awake
 *          assertion via IOKit.
 *
 * Linux:   Spawns `systemd-inhibit --what=idle ... sleep infinity`
 *          which takes an idle inhibitor lock via logind.
 *          Falls back silently if systemd-inhibit is not available
 *          (e.g. non-systemd distros).
 *
 * Termux:  Runs `termux-wake-lock` on start and
 *          `termux-wake-unlock` on shutdown.
 *
 * Windows: Spawns a PowerShell process that calls
 *          SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)
 *          via kernel32.dll P/Invoke, then waits forever. Killing the
 *          process releases the execution state automatically.
 *
 * On all platforms only idle sleep is affected — display sleep,
 * lid-close sleep, and explicit user-initiated sleep work normally.
 * The machine is kept awake only while the agent is running (not
 * while waiting for user input).
 *
 * A process.on('exit') handler acts as a safety net so that the
 * inhibitor is always cleaned up, even if pi exits without firing
 * session_shutdown (e.g. uncaught exception).
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { platform } from "node:os";

type CommandSpec = { cmd: string; args: string[] };
type Inhibitor = { start(): void; stop(): void };

function runCommandOrThrow(command: CommandSpec): void {
	const result = spawnSync(command.cmd, command.args, {
		stdio: "ignore",
	});

	if (result.error) {
		throw new Error(`Command failed: ${command.cmd}: ${result.error.message}`);
	}
	if (result.signal || result.status !== 0) {
		throw new Error(`Command failed: ${command.cmd}: exit=${result.status} signal=${result.signal}`);
	}
}

function createProcessInhibitor(command: CommandSpec): Inhibitor {
	let proc: ChildProcess | null = null;

	return {
		start() {
			if (proc) return;

			const child = spawn(command.cmd, command.args, {
				stdio: "ignore",
				detached: false,
			});

			proc = child;

			// If the command isn't found (e.g. no systemd-inhibit on a
			// non-systemd Linux), silently disable the inhibitor.
			child.on("error", () => {
				if (proc === child) proc = null;
			});

			child.on("exit", () => {
				if (proc === child) proc = null;
			});
		},

		stop() {
			if (!proc) return;

			const child = proc;
			proc = null;

			// On Windows, SIGTERM is not supported — ChildProcess.kill()
			// terminates the process tree. On Unix, SIGTERM is clean.
			child.kill();
		},
	};
}

function createCommandInhibitor(
	engage: CommandSpec,
	disengage: CommandSpec,
): Inhibitor {
	let active = false;

	return {
		start() {
			if (active) return;
			try {
				runCommandOrThrow(engage);
				active = true;
			} catch {
				// Gracefully degrade if command unavailable (e.g. missing termux-wake-lock)
			}
		},

		stop() {
			if (!active) return;
			try {
				runCommandOrThrow(disengage);
			} catch {
				// Best-effort cleanup
			}
			active = false;
		},
	};
}

function createInhibitor(): Inhibitor | null {
	if (process.env.TERMUX_VERSION) {
		return createCommandInhibitor(
			{ cmd: "termux-wake-lock", args: [] },
			{ cmd: "termux-wake-unlock", args: [] },
		);
	}

	switch (platform()) {
		case "darwin":
			return createProcessInhibitor({
				cmd: "caffeinate",
				args: ["-i"],
			});

		case "linux":
			return createProcessInhibitor({
				cmd: "systemd-inhibit",
				args: [
					"--what=idle",
					"--who=pi-caffeinate",
					"--why=Keeping machine awake for Pi agent",
					"--mode=block",
					"sleep",
					"infinity",
				],
			});

		case "win32":
			return createProcessInhibitor({
				cmd: "powershell.exe",
				args: [
					"-NoProfile",
					"-NoLogo",
					"-WindowStyle",
					"Hidden",
					"-Command",
					[
						"Add-Type -MemberDefinition",
						"'[DllImport(\"kernel32.dll\")] public static extern uint SetThreadExecutionState(uint esFlags);'",
						"-Name NativeMethods -Namespace Win32;",
						"[Win32.NativeMethods]::SetThreadExecutionState(0x80000001);",
						"[Threading.Thread]::Sleep([Threading.Timeout]::Infinite)",
					].join(" "),
				],
			});

		default:
			return null;
	}
}

export default function (pi: ExtensionAPI) {
	const inhibitor = createInhibitor();
	if (!inhibitor) return;

	process.on("exit", () => {
		inhibitor.stop();
	});

	pi.on("agent_start", () => {
		inhibitor.start();
	});

	pi.on("agent_end", () => {
		inhibitor.stop();
	});

	pi.on("session_shutdown", () => {
		inhibitor.stop();
	});
}
