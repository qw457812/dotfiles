import type { AssistantMessage } from "@mariozechner/pi-ai";
import type {
  AgentEndEvent,
  ExtensionContext,
} from "@mariozechner/pi-coding-agent";

interface Theme {
  fg(color: string, text: string): string;
}

function isAssistantMessage(message: unknown): message is AssistantMessage {
  if (!message || typeof message !== "object") return false;
  const role = (message as { role?: unknown }).role;
  return role === "assistant";
}

export interface TpsTracker {
  onSessionStart(): void;
  onAgentStart(): void;
  onAgentEnd(event: AgentEndEvent, ctx: ExtensionContext): boolean;
  getTps(theme: Theme): string | null;
}

export function createTpsTracker(): TpsTracker {
  let agentStartMs: number | null = null;
  let totalOutput = 0;
  let totalElapsedMs = 0;

  return {
    onSessionStart() {
      agentStartMs = null;
      totalOutput = 0;
      totalElapsedMs = 0;
    },

    onAgentStart() {
      agentStartMs = Date.now();
    },

    onAgentEnd(event: AgentEndEvent, ctx: ExtensionContext): boolean {
      if (!ctx.hasUI) return false;
      if (agentStartMs === null) return false;

      const elapsedMs = Date.now() - agentStartMs;
      agentStartMs = null;
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
      if (totalElapsedMs <= 0) {
        return null;
      }

      const averageTokensPerSecond = totalOutput / (totalElapsedMs / 1000);
      return theme.fg("muted", ` ${averageTokensPerSecond.toFixed(1)}`);
    },
  };
}
