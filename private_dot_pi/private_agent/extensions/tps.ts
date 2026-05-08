// Ref:
// https://github.com/badlogic/pi-mono/blob/a26a9cfabd05ccf774045b3685e50d3605516cdb/.pi/extensions/tps.ts
// https://github.com/monotykamary/pi-tps/blob/64472f2ccddc327e33ed604d69e94e152a659ac9/extensions/pi-tps/index.ts

import type { AssistantMessage, AssistantMessageEvent } from "@earendil-works/pi-ai";
import type {
	AgentEndEvent,
	ExtensionAPI,
	ExtensionContext,
	TurnEndEvent,
	TurnStartEvent,
} from "@earendil-works/pi-coding-agent";

interface MessageUpdateEvent {
	type: "message_update";
	message: unknown;
	assistantMessageEvent: AssistantMessageEvent;
}

interface MessageEndEvent {
	type: "message_end";
	message: unknown;
}

interface TurnTiming {
	turnStartMs: number;
	firstTokenMs: number | null;
	currentGenerationStartMs: number | null;
	assistantMessages: AssistantMessage[];
	generationMs: number;
}

interface TurnMetrics {
	ttftMs: number | null;
	generationMs: number;
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	totalTokens: number;
}

function isAssistantMessage(message: unknown): message is AssistantMessage {
	if (!message || typeof message !== "object") return false;
	const role = (message as { role?: unknown }).role;
	return role === "assistant";
}

function isFirstTokenEvent({ type }: AssistantMessageEvent) {
	return type === "thinking_delta" || type === "text_delta" || type === "toolcall_delta";
}

function buildTurnMetrics(turn: TurnTiming): TurnMetrics | null {
	let input = 0;
	let output = 0;
	let cacheRead = 0;
	let cacheWrite = 0;
	let totalTokens = 0;

	for (const message of turn.assistantMessages) {
		input += message.usage.input || 0;
		output += message.usage.output || 0;
		cacheRead += message.usage.cacheRead || 0;
		cacheWrite += message.usage.cacheWrite || 0;
		totalTokens += message.usage.totalTokens || 0;
	}

	if (output <= 0 || turn.generationMs <= 0) return null;

	return {
		ttftMs: turn.firstTokenMs === null ? null : turn.firstTokenMs - turn.turnStartMs,
		generationMs: turn.generationMs,
		input,
		output,
		cacheRead,
		cacheWrite,
		totalTokens,
	};
}

function formatDecimal(n: number, digits: number): string {
	return n.toFixed(digits).replace(/\.?0+$/, "");
}

function formatDuration(ms: number): string {
	const s = ms / 1000;
	if (s < 60) return `${formatDecimal(s, 1)}s`;
	const m = Math.floor(s / 60);
	const rs = Math.floor(s % 60);
	return `${m}m${rs}s`;
}

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${formatDecimal(count / 1000, 1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	if (count < 10000000) return `${formatDecimal(count / 1000000, 1)}M`;
	return `${Math.round(count / 1000000)}M`;
}

export default function (pi: ExtensionAPI) {
	let agentStartMs: number | null = null;
	let currentTurn: TurnTiming | null = null;
	let turnMetrics: TurnMetrics[] = [];
	let turnCount = 0;

	pi.on("agent_start", () => {
		agentStartMs = performance.now();
		currentTurn = null;
		turnMetrics = [];
		turnCount = 0;
	});

	pi.on("turn_start", (_event: TurnStartEvent) => {
		turnCount++;
		currentTurn = {
			turnStartMs: performance.now(),
			firstTokenMs: null,
			currentGenerationStartMs: null,
			assistantMessages: [],
			generationMs: 0,
		};
	});

	pi.on("message_update", (event: MessageUpdateEvent) => {
		if (!currentTurn) return;
		if (!isAssistantMessage(event.message)) return;
		if (!isFirstTokenEvent(event.assistantMessageEvent)) return;

		const now = performance.now();
		if (currentTurn.firstTokenMs === null) {
			currentTurn.firstTokenMs = now;
		}
		if (currentTurn.currentGenerationStartMs === null) {
			currentTurn.currentGenerationStartMs = now;
		}
	});

	pi.on("message_end", (event: MessageEndEvent) => {
		if (!currentTurn) return;
		if (!isAssistantMessage(event.message)) return;

		const now = performance.now();
		if (currentTurn.currentGenerationStartMs !== null) {
			currentTurn.generationMs += now - currentTurn.currentGenerationStartMs;
			currentTurn.currentGenerationStartMs = null;
		}
		currentTurn.assistantMessages.push(event.message);
	});

	pi.on("turn_end", (_event: TurnEndEvent) => {
		if (!currentTurn) return;

		const metrics = buildTurnMetrics(currentTurn);
		if (metrics) {
			turnMetrics.push(metrics);
		}
		currentTurn = null;
	});

	pi.on("agent_end", (_event: AgentEndEvent, ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		if (agentStartMs === null) return;

		const agentElapsedMs = performance.now() - agentStartMs;
		agentStartMs = null;
		currentTurn = null;

		if (agentElapsedMs <= 0 || turnMetrics.length === 0) return;

		let input = 0;
		let output = 0;
		let cacheRead = 0;
		let cacheWrite = 0;
		let totalTokens = 0;
		let totalGenerationMs = 0;
		let totalTtftMs = 0;
		let ttftCount = 0;

		for (const turn of turnMetrics) {
			input += turn.input;
			output += turn.output;
			cacheRead += turn.cacheRead;
			cacheWrite += turn.cacheWrite;
			totalTokens += turn.totalTokens;
			totalGenerationMs += turn.generationMs;
			if (turn.ttftMs !== null) {
				totalTtftMs += turn.ttftMs;
				ttftCount++;
			}
		}

		turnMetrics = [];
		if (output <= 0 || totalGenerationMs <= 0) return;

		const parts = [
			`${turnCount} ${turnCount === 1 ? "turn" : "turns"}`,
			`TPS ${formatDecimal(output / (totalGenerationMs / 1000), 1)}`,
			...(ttftCount > 0 ? [`TTFT ${formatDuration(totalTtftMs / ttftCount)}`] : []),
			`Gen ${formatDuration(totalGenerationMs)}/${formatDuration(agentElapsedMs)}`,
			[
				`↑${formatTokens(input)}`,
				`↓${formatTokens(output)}`,
				cacheRead > 0 ? `R${formatTokens(cacheRead)}` : "",
				cacheWrite > 0 ? `W${formatTokens(cacheWrite)}` : "",
				`Σ${formatTokens(totalTokens)}`,
			]
				.filter(Boolean)
				.join(" "),
		];
		ctx.ui.notify(parts.join(" · "), "info");
		turnCount = 0;
	});
}
