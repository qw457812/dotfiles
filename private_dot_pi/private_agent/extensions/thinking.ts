import type { Model, ModelThinkingLevel } from "@earendil-works/pi-ai";
import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ORDERED_LEVELS: ModelThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh"];

const MAX_LEVEL_PROVIDERS = new Set([
  "github-copilot",
  "zai",
  "deepseek",
  "xiaomi",
  "neuralwatt",
  "synthetic",
  "codebuddy",
  "crofai",
  "makora",
]);

function getSupportedLevels(model: Model<any> | undefined): ModelThinkingLevel[] {
  return model ? (getSupportedThinkingLevels(model) as ModelThinkingLevel[]) : ORDERED_LEVELS;
}

function getMaxLevel(model: Model<any>): ModelThinkingLevel {
  const levels = getSupportedLevels(model);
  for (let i = ORDERED_LEVELS.length - 1; i >= 0; i--) {
    if (levels.includes(ORDERED_LEVELS[i])) return ORDERED_LEVELS[i];
  }
  return "off";
}

function setLevelIfSupported(pi: ExtensionAPI, model: Model<any>, level: ModelThinkingLevel) {
  if (pi.getThinkingLevel() !== level && getSupportedLevels(model).includes(level)) {
    pi.setThinkingLevel(level);
  }
}

export default function (pi: ExtensionAPI) {
  // Auto thinking level on model change
  pi.on("model_select", async (event, _ctx) => {
    const { model, source } = event;
    const { provider, id } = model;
    if (source !== "set" && source !== "cycle") return;

    if (
      (provider === "openai-codex" || provider === "freemodel") &&
      (id === "gpt-5.5" || id === "gpt-5.4")
    ) {
      setLevelIfSupported(pi, model, "high");
      return;
    }

    // request-based billing or non-frontier open-source models
    if (MAX_LEVEL_PROVIDERS.has(provider)) {
      setLevelIfSupported(pi, model, getMaxLevel(model));
    }
  });

  pi.registerCommand("thinking", {
    description: "Set the thinking level",
    handler: async (_args, ctx) => {
      const supported = [...getSupportedLevels(ctx.model)].reverse();
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
