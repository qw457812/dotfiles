// Copied from: https://github.com/badlogic/pi-mono/blob/a26a9cfabd05ccf774045b3685e50d3605516cdb/.pi/extensions/tps.ts

import type { AssistantMessage, AssistantMessageEvent } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

function isAssistantMessage(message: unknown): message is AssistantMessage {
	if (!message || typeof message !== "object") return false;
	const role = (message as { role?: unknown }).role;
	return role === "assistant";
}

function isFirstTokenEvent({ type }: AssistantMessageEvent) {
	return type === "thinking_delta" || type === "text_delta";
}

export default function (pi: ExtensionAPI) {
	let agentStartMs: number | null = null;
	let agentTtftMs: number | null = null;
	let turnCount = 0;

	pi.on("agent_start", () => {
		agentStartMs = Date.now();
		agentTtftMs = null;
		turnCount = 0;
	});

	pi.on("turn_start", () => {
		turnCount++;
	});

	pi.on("message_update", (event) => {
		if (agentStartMs === null || agentTtftMs !== null) return;
		if (!isAssistantMessage(event.message)) return;
		if (!isFirstTokenEvent(event.assistantMessageEvent)) return;

		agentTtftMs = Date.now() - agentStartMs;
	});

	pi.on("agent_end", (event, ctx) => {
		if (!ctx.hasUI) return;
		if (agentStartMs === null) return;

		const elapsedMs = Date.now() - agentStartMs;
		agentStartMs = null;
		if (elapsedMs <= 0) return;

		let input = 0;
		let output = 0;
		let cacheRead = 0;
		let cacheWrite = 0;
		let totalTokens = 0;

		for (const message of event.messages) {
			if (!isAssistantMessage(message)) continue;
			input += message.usage.input || 0;
			output += message.usage.output || 0;
			cacheRead += message.usage.cacheRead || 0;
			cacheWrite += message.usage.cacheWrite || 0;
			totalTokens += message.usage.totalTokens || 0;
		}

		if (output <= 0) return;

		const elapsedSeconds = elapsedMs / 1000;
		const tokensPerSecond = output / elapsedSeconds;
		const metrics = [
			`TPS ${tokensPerSecond.toFixed(1)} tok/s`,
			...(agentTtftMs !== null ? [`TTFT ${(agentTtftMs / 1000).toFixed(1)}s`] : []),
			`out ${output.toLocaleString()}`,
			`in ${input.toLocaleString()}`,
			`cache r/w ${cacheRead.toLocaleString()}/${cacheWrite.toLocaleString()}`,
			`total ${totalTokens.toLocaleString()}`,
			`${turnCount} turn(s)`,
			`${elapsedSeconds.toFixed(1)}s`,
		];
		ctx.ui.notify(metrics.join(", "), "info");
		agentTtftMs = null;
		turnCount = 0;
	});
}
