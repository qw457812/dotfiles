/**
 * thinking.ts - thinking-level command and model-switch defaults
 *
 * Commands:
 *   /thinking          Open a picker containing the current model's supported levels.
 *   /thinking <level>  Set the level directly, with model-aware completion and validation.
 *
 * Automatic defaults apply only to explicit model selection and model cycling:
 *   - openai-codex/gpt-5.6-sol uses medium.
 *   - Selected OpenAI frontier models use high.
 *   - Request-billed and non-frontier open-source providers use their maximum supported level.
 *
 * Session restore is left unchanged, and an explicit /thinking argument always takes effect
 * immediately without opening the picker.
 */

import type { Model, ModelThinkingLevel } from "@earendil-works/pi-ai";
import { getSupportedThinkingLevels } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

const ORDERED_LEVELS: ModelThinkingLevel[] = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
];

const MAX_LEVEL_PROVIDERS = new Set([
  "kiro",
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

function getThinkingLevelCompletions(
  model: Model<any> | undefined,
  prefix: string,
): AutocompleteItem[] | null {
  const matches = getSupportedLevels(model).filter((level) => level.startsWith(prefix.trimStart()));
  if (matches.length === 0) return null;
  return matches.map((level) => ({ value: level, label: level }));
}

export default function (pi: ExtensionAPI) {
  let currentModel: Model<any> | undefined;

  pi.on("session_start", (_event, ctx) => {
    currentModel = ctx.model;
  });

  // Auto thinking level on model change
  pi.on("model_select", async (event, _ctx) => {
    const { model, source } = event;
    currentModel = model;
    const { provider, id } = model;
    if (source !== "set" && source !== "cycle") return;

    if (provider === "openai-codex" && id === "gpt-5.6-sol") {
      setLevelIfSupported(pi, model, "medium");
      return;
    }

    if (provider === "openai-codex" && id === "gpt-5.4-mini") {
      setLevelIfSupported(pi, model, "off");
      return;
    }

    if (
      (provider === "openai-codex" || provider === "github-copilot" || provider === "freemodel") &&
      (id === "gpt-5.5" || id === "gpt-5.6-terra" || id === "gpt-5.4" || id === "gpt-5.6-luna")
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
    description: "Set the thinking level (off|minimal|low|medium|high|xhigh|max)",
    getArgumentCompletions: (prefix) => getThinkingLevelCompletions(currentModel, prefix),
    handler: async (args, ctx) => {
      const supported = getSupportedLevels(ctx.model);
      const arg = args.trim();
      let target: ModelThinkingLevel | undefined;

      if (arg) {
        if (!supported.includes(arg as ModelThinkingLevel)) {
          ctx.ui.notify(
            `Unsupported thinking level "${arg}". Supported: ${supported.join(", ")}`,
            "error",
          );
          return;
        }
        target = arg as ModelThinkingLevel;
      } else {
        const current = pi.getThinkingLevel();
        const available = [...supported].reverse().filter((level) => level !== current);
        const selected = await ctx.ui.select(`Thinking level (current: ${current})`, available);
        target = available.find((level) => level === selected);
        if (!target) return;
      }

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
