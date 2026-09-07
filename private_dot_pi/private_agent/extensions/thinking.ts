/**
 * thinking.ts - model-switch thinking-level defaults
 *
 * Per-model defaults belong in /settings `modelThinkingLevels`. On switch,
 * MAX_LEVEL_PROVIDERS take precedence over those defaults. Restore and manual
 * /thinking are unchanged.
 */

import type { Model, ModelThinkingLevel } from "@earendil-works/pi-ai";
import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_LEVEL_PROVIDERS = new Set([
  "commandcode",
  "kiro",
  "zai",
  "deepseek",
  "xiaomi",
  "neuralwatt",
  "hyper",
  "synthetic",
  "codebuddy",
  "crofai",
  "coralbricks",
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
  pi.on("model_select", async (event, _ctx) => {
    const { model, source } = event;
    if (source !== "set" && source !== "cycle") return;

    // request-based billing or non-frontier open-source models
    if (MAX_LEVEL_PROVIDERS.has(model.provider)) {
      setLevelIfSupported(pi, model, getMaxLevel(model));
    }
  });
}
