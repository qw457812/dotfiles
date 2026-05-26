import type { Model, ModelThinkingLevel } from "@earendil-works/pi-ai";
import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const THINKING_LEVEL_ORDER: ModelThinkingLevel[] = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
];

function getMaxThinkingLevel(model: Model<any>): ModelThinkingLevel {
  const levels = getSupportedThinkingLevels(model);
  for (let i = THINKING_LEVEL_ORDER.length - 1; i >= 0; i--) {
    if (levels.includes(THINKING_LEVEL_ORDER[i])) return THINKING_LEVEL_ORDER[i];
  }
  return "off";
}

function setThinkingLevelIfSupported(
  pi: ExtensionAPI,
  model: Model<any>,
  level: ModelThinkingLevel,
) {
  if (pi.getThinkingLevel() !== level && getSupportedThinkingLevels(model).includes(level)) {
    pi.setThinkingLevel(level);
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("model_select", async (event, _ctx) => {
    const { model, source } = event;
    const { provider, id } = model;

    if (source !== "set" && source !== "cycle") return;

    if (provider === "openai-codex") {
      const levelMap: Record<string, ModelThinkingLevel> = {
        "gpt-5.5": "high",
        "gpt-5.4": "high",
        "gpt-5.4-mini": "off",
      };
      const level = levelMap[id];
      if (level) {
        setThinkingLevelIfSupported(pi, model, level);
        return;
      }
    }

    // request-based billing or non-frontier open-source models
    if (
      [
        "github-copilot",
        "crofai",
        "zai",
        "synthetic",
        "deepseek",
        "neuralwatt",
        "codebuddy",
      ].includes(provider)
    ) {
      setThinkingLevelIfSupported(pi, model, getMaxThinkingLevel(model));
    }
  });
}
