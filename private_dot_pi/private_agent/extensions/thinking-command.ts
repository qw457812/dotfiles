import type { ThinkingLevel } from "@earendil-works/pi-agent-core";
import type { Model } from "@earendil-works/pi-ai";
import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ALL_LEVELS: ThinkingLevel[] = ["xhigh", "high", "medium", "low", "minimal", "off"];

function getSupportedLevels(model: Model<any> | undefined): ThinkingLevel[] {
  return model ? [...(getSupportedThinkingLevels(model) as ThinkingLevel[])].reverse() : ALL_LEVELS;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("thinking", {
    description: "Set the thinking level",
    handler: async (_args, ctx) => {
      const supported = getSupportedLevels(ctx.model);
      const current = pi.getThinkingLevel();
      const available = supported.filter((level) => level !== current);
      const selected = await ctx.ui.select(`Thinking level (current: ${current})`, available);
      const target = available.find((level) => level === selected);
      if (!target) return;

      pi.setThinkingLevel(target);
      const actual = pi.getThinkingLevel();
      const message =
        actual === target
          ? `Thinking level set to ${actual}`
          : `Thinking level set to ${actual} (clamped)`;
      ctx.ui.notify(message, "info");
    },
  });
}
