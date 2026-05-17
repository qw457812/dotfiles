/**
 * Terminal Focus Tracking Extension
 *
 * Tracks terminal focus state via OSC 1004 escape sequences.
 * Emits `my:focus_change` events on the shared event bus for other
 * extensions to consume.
 *
 * See also:
 * - https://github.com/tmustier/pi-extensions/blob/8da9865e5beb625050406c0e9281e4393d076b22/session-recap/index.ts
 * - https://github.com/audibleblink/pi-harness/blob/b0e30a95aad74b80c8006097f80f710f0061c9fc/extensions/blur.ts
 */

import type { ExtensionAPI, ExtensionUIContext } from "@earendil-works/pi-coding-agent";

type FocusTracker = {
	attach: (ui?: Pick<ExtensionUIContext, "onTerminalInput">, onChange?: (focused: boolean) => void) => void;
	detach: () => void;
	// true = focused, false = unfocused, undefined = unknown
	isFocused: () => boolean | undefined;
};

// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
const FOCUS_ENABLE = "\x1b[?1004h";
const FOCUS_DISABLE = "\x1b[?1004l";
const FOCUS_IN = "\x1b[I";
const FOCUS_OUT = "\x1b[O";

const createFocusTracker = (): FocusTracker => {
	let focused: boolean | undefined;
	let offTerminalInput: (() => void) | undefined;

	const detach = () => {
		focused = undefined;
		if (!offTerminalInput) {
			return;
		}

		offTerminalInput();
		offTerminalInput = undefined;
		process.stdout.write(FOCUS_DISABLE);
	};

	const attach = (ui?: Pick<ExtensionUIContext, "onTerminalInput">, onChange?: (focused: boolean) => void) => {
		detach();
		if (!ui || !process.stdin.isTTY || !process.stdout.isTTY) {
			return;
		}

		process.stdout.write(FOCUS_ENABLE);
		offTerminalInput = ui.onTerminalInput((data: string) => {
			if (data === FOCUS_IN) {
				if (focused !== true) {
					focused = true;
					onChange?.(true);
				}
			} else if (data === FOCUS_OUT) {
				if (focused !== false) {
					focused = false;
					onChange?.(false);
				}
			}
			return {};
		});
	};

	return {
		attach,
		detach,
		isFocused: () => focused,
	};
};

export default function (pi: ExtensionAPI) {
	const focusTracker = createFocusTracker();

	pi.on("session_start", (_event, ctx) => {
		focusTracker.attach(ctx.hasUI ? ctx.ui : undefined, (focused) => {
			pi.events.emit("my:focus_change", { focused });
		});
	});

	pi.on("session_shutdown", () => {
		focusTracker.detach();
	});
}
