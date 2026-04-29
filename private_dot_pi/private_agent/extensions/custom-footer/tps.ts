import type { AssistantMessage, AssistantMessageEvent } from "@mariozechner/pi-ai";
import type { AgentEndEvent, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { formatDecimal } from "./utils";

interface Theme {
  fg(color: string, text: string): string;
}

function isAssistantMessage(message: unknown): message is AssistantMessage {
  if (!message || typeof message !== "object") return false;
  const role = (message as { role?: unknown }).role;
  return role === "assistant";
}

function isFirstTokenEvent({ type }: AssistantMessageEvent) {
  return type === "thinking_delta" || type === "text_delta" || type === "toolcall_delta";
}

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
  output: number;
}

function buildTurnMetrics(turn: TurnTiming): TurnMetrics | null {
  let output = 0;

  for (const message of turn.assistantMessages) {
    output += message.usage.output || 0;
  }

  if (output <= 0 || turn.generationMs <= 0) return null;

  return {
    ttftMs: turn.firstTokenMs === null ? null : turn.firstTokenMs - turn.turnStartMs,
    generationMs: turn.generationMs,
    output,
  };
}

export interface TpsTracker {
  onSessionStart(): void;
  onAgentStart(): void;
  onTurnStart(): void;
  onMessageUpdate(event: MessageUpdateEvent): void;
  onMessageEnd(event: MessageEndEvent): void;
  onTurnEnd(): boolean;
  onAgentEnd(event: AgentEndEvent, ctx: ExtensionContext): boolean;
  getTps(theme: Theme): string | null;
}

export function createTpsTracker(): TpsTracker {
  let currentTurn: TurnTiming | null = null;
  let totalTtftMs = 0;
  let ttftCount = 0;
  let totalOutput = 0;
  let totalGenerationMs = 0;

  return {
    onSessionStart() {
      currentTurn = null;
      totalTtftMs = 0;
      ttftCount = 0;
      totalOutput = 0;
      totalGenerationMs = 0;
    },

    onAgentStart() {
      currentTurn = null;
    },

    onTurnStart() {
      currentTurn = {
        turnStartMs: performance.now(),
        firstTokenMs: null,
        currentGenerationStartMs: null,
        assistantMessages: [],
        generationMs: 0,
      };
    },

    onMessageUpdate(event: MessageUpdateEvent) {
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
    },

    onMessageEnd(event: MessageEndEvent) {
      if (!currentTurn) return;
      if (!isAssistantMessage(event.message)) return;

      const now = performance.now();
      if (currentTurn.currentGenerationStartMs !== null) {
        currentTurn.generationMs += now - currentTurn.currentGenerationStartMs;
        currentTurn.currentGenerationStartMs = null;
      }
      currentTurn.assistantMessages.push(event.message);
    },

    onTurnEnd(): boolean {
      if (!currentTurn) return false;

      const metrics = buildTurnMetrics(currentTurn);
      currentTurn = null;
      if (!metrics) return false;

      totalOutput += metrics.output;
      totalGenerationMs += metrics.generationMs;
      if (metrics.ttftMs !== null) {
        totalTtftMs += metrics.ttftMs;
        ttftCount++;
      }
      return true;
    },

    onAgentEnd(_event: AgentEndEvent, ctx: ExtensionContext): boolean {
      currentTurn = null;
      return ctx.hasUI;
    },

    getTps(theme: Theme): string | null {
      const parts: string[] = [];
      if (totalGenerationMs > 0) {
        const avgTps = totalOutput / (totalGenerationMs / 1000);
        parts.push(theme.fg("syntaxComment", formatDecimal(avgTps, 1)));
      }
      if (ttftCount > 0) {
        const avgTtft = totalTtftMs / ttftCount / 1000;
        parts.push(theme.fg("muted", `${formatDecimal(avgTtft, 1)}s`));
      }
      return parts.length ? parts.join(theme.fg("muted", "/")) : null;
    },
  };
}
