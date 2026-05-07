// Ref:
// https://github.com/mitsuhiko/agent-stuff/blob/e2d2df778fedf9989975ce50c71e434a5ea15359/pi-extensions/notify.ts
// https://github.com/badlogic/pi-mono/blob/4351dd7cdc5806fd4c4e61aa534e7790b9a54947/packages/coding-agent/examples/extensions/notify.ts

/**
 * Desktop Notification Extension
 *
 * Sends a native desktop notification when the agent finishes and is waiting for input.
 * Uses OSC 777 escape sequence - no external dependencies.
 *
 * Supported terminals: Ghostty, iTerm2, WezTerm, rxvt-unicode
 * Not supported: Kitty (uses OSC 99), Terminal.app, Windows Terminal, Alacritty
 *
 * Note: inside Neovim's `:terminal`, OSC 99/777 are intercepted by Nvim and won't
 * reach the host terminal unless they are forwarded via `TermRequest` + `nvim_ui_send()`.
 */

import type { ExtensionAPI, ExtensionUIContext } from "@mariozechner/pi-coding-agent";
import { Markdown, type MarkdownTheme } from "@mariozechner/pi-tui";
import { spawn } from "node:child_process";

// requires `set -g allow-passthrough on` in tmux config
const wrapForTmux = (seq: string): string => {
	return process.env.TMUX ? `\x1bPtmux;${seq.replace(/\x1b/g, "\x1b\x1b")}\x1b\\` : seq;
};

const notifyOSC99 = (title: string, body: string): void => {
	const encode = (value: string): string => Buffer.from(value, "utf8").toString("base64");

	// Kitty OSC 99: i=notification id, d=0 means not done yet, p=body for second part, e=1 means base64 payload
	process.stdout.write(wrapForTmux(`\x1b]99;i=1:d=0:e=1;${encode(title)}\x1b\\`));
	process.stdout.write(wrapForTmux(`\x1b]99;i=1:p=body:e=1;${encode(body)}\x1b\\`));
};

const notifyOSC777 = (title: string, body: string): void => {
	const sanitize = (value: string): string => value.replace(/[\x00-\x1f\x7f\u0080-\u009f;]/g, " ").trim();

	// OSC 777 format: ESC ] 777 ; notify ; title ; body BEL
	// https://terminfo.dev/extensions/osc-777-notify
	process.stdout.write(wrapForTmux(`\x1b]777;notify;${sanitize(title)};${sanitize(body)}\x07`));
};

/**
 * Send a desktop notification via OSC 777 escape sequence.
 */
const notify = (title: string, body: string): void => {
	if (process.platform === "darwin") {
		const script = `on run argv
set notifTitle to item 1 of argv
set notifBody to item 2 of argv
display notification notifBody with title notifTitle
end run`;
		const proc = spawn("osascript", ["-e", script, "--", title, body], { stdio: "ignore" });
		proc.once("error", () => {});
		proc.unref();
	} else if (process.env.TERMUX_VERSION) {
		const proc = spawn("termux-notification", ["-t", title, "-c", body], { stdio: "ignore" });
		proc.once("error", () => {});
		proc.unref();
	} else if (process.env.KITTY_WINDOW_ID) {
		notifyOSC99(title, body);
	} else {
		notifyOSC777(title, body);
	}
};

type FocusTracker = {
	attach: (ui?: Pick<ExtensionUIContext, "onTerminalInput">) => void;
	detach: () => void;
	// true = focused, false = unfocused, undefined = unknown
	isFocused: () => boolean | undefined;
};

// See also: https://github.com/tmustier/pi-extensions/blob/8da9865e5beb625050406c0e9281e4393d076b22/session-recap/index.ts
const createFocusTracker = (): FocusTracker => {
	// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
	const FOCUS_ENABLE = "\x1b[?1004h";
	const FOCUS_DISABLE = "\x1b[?1004l";
	const FOCUS_IN = "\x1b[I";
	const FOCUS_OUT = "\x1b[O";

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

	const attach = (ui?: Pick<ExtensionUIContext, "onTerminalInput">) => {
		detach();
		if (!ui || !process.stdin.isTTY || !process.stdout.isTTY) {
			return;
		}

		process.stdout.write(FOCUS_ENABLE);
		offTerminalInput = ui.onTerminalInput((data: string) => {
			if (data === FOCUS_IN) {
				focused = true;
			} else if (data === FOCUS_OUT) {
				focused = false;
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

type FocusAwareNotifier = {
	notify: (title: string, body: string) => void;
};

const createFocusAwareNotifier = (pi: ExtensionAPI): FocusAwareNotifier => {
	const focusTracker = createFocusTracker();

	pi.on("session_start", async (_event, ctx) => {
		focusTracker.attach(ctx.hasUI ? ctx.ui : undefined);
	});

	pi.on("session_shutdown", async () => {
		focusTracker.detach();
	});

	return {
		notify: (title: string, body: string) => {
			if (focusTracker.isFocused() !== true) {
				notify(title, body);
			}
		},
	};
};

const isTextPart = (part: unknown): part is { type: "text"; text: string } =>
	Boolean(part && typeof part === "object" && "type" in part && part.type === "text" && "text" in part);

const extractLastAssistantText = (messages: Array<{ role?: string; content?: unknown }>): string | null => {
	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];
		if (message?.role !== "assistant") {
			continue;
		}

		const content = message.content;
		if (typeof content === "string") {
			return content.trim() || null;
		}

		if (Array.isArray(content)) {
			const text = content.filter(isTextPart).map((part) => part.text).join("\n").trim();
			return text || null;
		}

		return null;
	}

	return null;
};

const plainMarkdownTheme: MarkdownTheme = {
	heading: (text) => text,
	link: (text) => text,
	linkUrl: () => "",
	code: (text) => text,
	codeBlock: (text) => text,
	codeBlockBorder: () => "",
	quote: (text) => text,
	quoteBorder: () => "",
	hr: () => "",
	listBullet: () => "",
	bold: (text) => text,
	italic: (text) => text,
	strikethrough: (text) => text,
	underline: (text) => text,
};

const simpleMarkdown = (text: string, width = 80): string => {
	const markdown = new Markdown(text, 0, 0, plainMarkdownTheme);
	return markdown.render(width).join("\n");
};

const formatNotification = (text: string | null): { title: string; body: string } => {
	const simplified = text ? simpleMarkdown(text) : "";
	const normalized = simplified.replace(/\s+/g, " ").trim();
	if (!normalized) {
		return { title: "Ready for input", body: "" };
	}

	const maxBody = 200;
	const body = normalized.length > maxBody ? `${normalized.slice(0, maxBody - 1)}…` : normalized;
	return { title: "π", body };
};

export default function (pi: ExtensionAPI) {
	const notifier = createFocusAwareNotifier(pi);

	const offMyNotification = pi.events.on("my:notification", (data: unknown) => {
		const { title, body } = data as { title: string; body: string };
		notifier.notify(title, body);
	});

	// https://github.com/aliou/pi-guardrails/blob/ba06d720196c68825274f652dadd1032260f64ad/src/utils/events.ts#L31
	const offGuardrailsDangerous = pi.events.on("guardrails:dangerous", (data: unknown) => {
		const { command, description, pattern } = data as { command: string; description: string; pattern: string; };
		notifier.notify("pi-guardrails:dangerous", `${command}\n${description}\n${pattern}`);
	});

	pi.on("agent_end", async (event) => {
		const lastText = extractLastAssistantText(event.messages ?? []);
		const { title, body } = formatNotification(lastText);
		notifier.notify(title, body);
	});

	pi.on("session_shutdown", async () => {
		offMyNotification();
		offGuardrailsDangerous();
	});
}
