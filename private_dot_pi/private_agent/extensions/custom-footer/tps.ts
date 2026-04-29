import type { AssistantMessage, AssistantMessageEvent } from "@mariozechner/pi-ai";
import type {
  AgentEndEvent,
  ExtensionContext,
  MessageUpdateEvent,
} from "@mariozechner/pi-coding-agent";
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
  return type === "thinking_delta" || type === "text_delta";
}

export interface TpsTracker {
  onSessionStart(): void;
  onAgentStart(): void;
  onMessageUpdate(event: MessageUpdateEvent): void;
  onAgentEnd(event: AgentEndEvent, ctx: ExtensionContext): boolean;
  getTps(theme: Theme): string | null;
}

export function createTpsTracker(): TpsTracker {
  let agentStartMs: number | null = null;
  let agentTtftMs: number | null = null;
  let totalTtftMs = 0;
  let ttftCount = 0;
  let totalOutput = 0;
  let totalElapsedMs = 0;

  return {
    onSessionStart() {
      agentStartMs = null;
      agentTtftMs = null;
      totalTtftMs = 0;
      ttftCount = 0;
      totalOutput = 0;
      totalElapsedMs = 0;
    },

    onAgentStart() {
      agentStartMs = Date.now();
      agentTtftMs = null;
    },

    onMessageUpdate(event: MessageUpdateEvent) {
      if (agentStartMs === null || agentTtftMs !== null) return;
      if (!isAssistantMessage(event.message)) return;
      if (!isFirstTokenEvent(event.assistantMessageEvent)) return;

      agentTtftMs = Date.now() - agentStartMs;
      totalTtftMs += agentTtftMs;
      ttftCount++;
    },

    onAgentEnd(event: AgentEndEvent, ctx: ExtensionContext): boolean {
      if (!ctx.hasUI) return false;
      if (agentStartMs === null) return false;

      const elapsedMs = Date.now() - agentStartMs;
      agentStartMs = null;
      agentTtftMs = null;
      if (elapsedMs <= 0) return false;

      let output = 0;
      for (const message of event.messages) {
        if (!isAssistantMessage(message)) continue;
        output += message.usage.output || 0;
      }

      if (output <= 0) return false;

      totalOutput += output;
      totalElapsedMs += elapsedMs;
      return true;
    },

    getTps(theme: Theme): string | null {
      const parts: string[] = [];
      if (totalElapsedMs > 0) {
        const avgTps = totalOutput / (totalElapsedMs / 1000);
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
