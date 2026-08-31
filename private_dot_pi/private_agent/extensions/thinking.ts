/**
 * thinking.ts - model-switch thinking-level defaults
 *
 * Pi provides the built-in /thinking command and picker.
 *
 * Automatic defaults apply only to explicit model selection and model cycling:
 *   - Models listed in MODEL_LEVELS use their configured level.
 *   - Providers listed in MAX_LEVEL_PROVIDERS use their highest supported level.
 *   - All other models keep the current session level.
 *
 * Session restore and Pi's built-in /thinking behavior are left unchanged.
 */

import type { Model, ModelThinkingLevel } from "@earendil-works/pi-ai";
import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MODEL_LEVELS: Record<string, Partial<Record<string, ModelThinkingLevel>>> = {
  "openai-codex": {
    "gpt-5.6-sol": "medium",
    "gpt-5.6-terra": "high",
    "gpt-5.6-luna": "max",
    "gpt-5.5": "high",
    "gpt-5.4": "high",
  },
  commandcode: {
    "deepseek/deepseek-v4-flash": "max",
  },
};

const MAX_LEVEL_PROVIDERS = new Set([
  "kiro",
  "zai",
  "deepseek",
  "xiaomi",
  "neuralwatt",
  "synthetic",
  "codebuddy",
  "crofai",
]);

const ORDERED_LEVELS: ModelThinkingLevel[] = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
];

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

    const level = MODEL_LEVELS[provider]?.[id];
    if (level) {
      setLevelIfSupported(pi, model, level);
      return;
    }

    // request-based billing or non-frontier open-source models
    if (MAX_LEVEL_PROVIDERS.has(provider)) {
      setLevelIfSupported(pi, model, getMaxLevel(model));
    }
  });
}
