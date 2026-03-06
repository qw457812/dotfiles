/**
 * Ref: https://github.com/badlogic/pi-mono/blob/7b902612e96a8bf49cf6f34345f09a44e5ca6926/packages/coding-agent/examples/extensions/custom-footer.ts

 * Custom Footer Extension - demonstrates ctx.ui.setFooter()
 *
 * footerData exposes data not otherwise accessible:
 * - getGitBranch(): current git branch
 * - getExtensionStatuses(): texts from ctx.ui.setStatus()
 *
 * Token stats come from ctx.sessionManager/ctx.model (already accessible).
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
} from "@mariozechner/pi-coding-agent";
import { type TUI, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

export default function (pi: ExtensionAPI) {
  let enabled = true;

  function createFooterFactory(ctx: ExtensionContext) {
    return (
      tui: TUI,
      theme: { fg(color: string, text: string): string },
      footerData: ReadonlyFooterDataProvider,
    ) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          // Compute tokens from ctx (already accessible to extensions)
          let input = 0,
            output = 0,
            cost = 0;
          for (const e of ctx.sessionManager.getBranch()) {
            if (e.type === "message" && e.message.role === "assistant") {
              const m = e.message as AssistantMessage;
              input += m.usage.input;
              output += m.usage.output;
              cost += m.usage.cost.total;
            }
          }

          // Get git branch (not otherwise accessible)
          const branch = footerData.getGitBranch();
          const fmt = (n: number) =>
            n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`;

          const left = theme.fg(
            "dim",
            `↑${fmt(input)} ↓${fmt(output)} $${cost.toFixed(3)}`,
          );
          const branchStr = branch ? ` (${branch})` : "";
          const right = theme.fg(
            "dim",
            `${ctx.model?.id || "no-model"}${branchStr}`,
          );

          const pad = " ".repeat(
            Math.max(1, width - visibleWidth(left) - visibleWidth(right)),
          );
          return [truncateToWidth(left + pad + right, width)];
        },
      };
    };
  }

  // Set custom footer as default on startup
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setFooter(createFooterFactory(ctx));
  });

  pi.registerCommand("footer", {
    description: "Toggle custom footer",
    handler: async (_args, ctx) => {
      enabled = !enabled;

      if (enabled) {
        ctx.ui.setFooter(createFooterFactory(ctx));
        ctx.ui.notify("Custom footer enabled", "info");
      } else {
        ctx.ui.setFooter(undefined);
        ctx.ui.notify("Default footer restored", "info");
      }
    },
  });
}
