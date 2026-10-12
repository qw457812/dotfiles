// Ref: https://github.com/disler/pi-vs-claude-code/blob/32dfe122cb6d444e91c68b32597274a725d81fa3/extensions/tool-counter.ts

import type { ExtensionContext, ToolExecutionEndEvent } from "@earendil-works/pi-coding-agent";

interface Theme {
  fg(color: string, text: string): string;
}

export interface ToolCounterTracker {
  onToolExecutionEnd(event: ToolExecutionEndEvent): void;
  onSessionStart(ctx: ExtensionContext): void;
  getToolTally(theme: Theme): string | null;
}

export function createToolCounter(): ToolCounterTracker {
  let counts: Record<string, { success: number; error: number }> = {};

  function count(name: string, isError: boolean): void {
    const c = (counts[name] ??= { success: 0, error: 0 });
    c[isError ? "error" : "success"]++;
  }

  return {
    onToolExecutionEnd(event) {
      count(event.toolName, event.isError);
    },

    onSessionStart(ctx) {
      counts = {};
      for (const entry of ctx.sessionManager.getEntries()) {
        if (entry.type !== "message") continue;
        const message = entry.message;
        if (message.role !== "toolResult") continue;
        count(message.toolName, message.isError);
        for (const call of message.nestedCalls?.calls ?? []) {
          count(call.name, call.status !== "ok");
        }
      }
    },

    getToolTally(theme) {
      const entries = Object.entries(counts);
      if (entries.length === 0) {
        return null;
      }
      entries.sort(([a], [b]) => a.localeCompare(b));
      return entries
        .map(([name, { success, error }]) => {
          const parts = [theme.fg("dim", name)];
          if (success > 0) parts.push(theme.fg("dim", `${success}`));
          if (error > 0) parts.push(theme.fg("error", `${error}`));
          return parts.join(" ");
        })
        .join(" ");
    },
  };
}
