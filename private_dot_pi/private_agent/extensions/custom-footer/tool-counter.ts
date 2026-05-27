// Ref: https://github.com/disler/pi-vs-claude-code/blob/32dfe122cb6d444e91c68b32597274a725d81fa3/extensions/tool-counter.ts

interface Theme {
  fg(color: string, text: string): string;
}

export interface ToolCounterTracker {
  onToolExecutionEnd(event: { toolName: string; isError: boolean }): void;
  onSessionStart(): void;
  getToolTally(theme: Theme): string | null;
}

export function createToolCounter(): ToolCounterTracker {
  let counts: Record<string, { success: number; error: number }> = {};

  return {
    onToolExecutionEnd(event) {
      const c = (counts[event.toolName] ??= { success: 0, error: 0 });
      c[event.isError ? "error" : "success"]++;
    },

    onSessionStart() {
      counts = {};
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
        .join(theme.fg("dim", " | "));
    },
  };
}
