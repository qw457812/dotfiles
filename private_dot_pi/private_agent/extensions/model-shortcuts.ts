/**
 * model-shortcuts.ts - quick model switch commands
 *
 *   /<alias> [level]  e.g. /sol high
 *
 * The optional level must be one of the model's supported thinking levels.
 * Without an argument, the current thinking level carries over (thinking.ts
 * may auto-adjust it on model_select).
 * https://github.com/qw457812/dotfiles/blob/1d26e44cc5dce1c044d331ec54d638df941839d7/private_dot_pi/private_agent/extensions/thinking.ts
 */
import { getSupportedThinkingLevels, type ModelThinkingLevel } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

const ALIASES: Record<string, ModelTarget> = {
  sol: { provider: "openai-codex", id: "gpt-5.6-sol" },
  terra: { provider: "openai-codex", id: "gpt-5.6-terra" },
  luna: { provider: "openai-codex", id: "gpt-5.6-luna" },
  glm: { provider: "commandcode", id: "zai-org/GLM-5.3" },
  glmflash: { provider: "commandcode", id: "z-ai/glm-5.3-flash" },
  ds: { provider: "commandcode", id: "deepseek/deepseek-v4-pro" },
  dsflash: { provider: "neuralwatt", id: "deepseek-v4-flash" },
  kimi: { provider: "neuralwatt", id: "kimi-k3" },
  qwen: { provider: "commandcode", id: "Qwen/Qwen3.8-Max" },
  mimo: { provider: "commandcode", id: "xiaomi/mimo-v2.5-pro" },
  flex: { provider: "neuralwatt", id: "kimi-k3-flex" },
  cmd: { provider: "commandcode", id: "deepseek/deepseek-v4-flash" },
  hyper: { provider: "hyper", id: "glm-5.3-flash" },
  buddy: { provider: "codebuddy", id: "glm-5.3" },
};

const ALL_LEVELS: ModelThinkingLevel[] = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
];

type ModelTarget = { provider: string; id: string };

async function switchModel(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  target: ModelTarget,
  args: string,
) {
  const label = `${target.provider}/${target.id}`;
  const model = ctx.modelRegistry.find(target.provider, target.id);
  if (!model) {
    ctx.ui.notify(`Model not found: ${label}`, "error");
    return;
  }

  const supported = getSupportedThinkingLevels(model);
  const arg = args.trim();
  const level = arg ? (arg as ModelThinkingLevel) : undefined;
  if (level && !supported.includes(level)) {
    ctx.ui.notify(
      `Unsupported thinking level "${arg}" for ${target.id}. Supported: ${supported.join(", ")}`,
      "error",
    );
    return;
  }

  // setModel awaits model_select handlers (e.g. thinking.ts auto-level),
  // so applying the requested level afterwards takes precedence.
  if (!(await pi.setModel(model))) {
    ctx.ui.notify(`No API key for ${label}`, "error");
    return;
  }

  if (level) {
    pi.setThinkingLevel(level);
    ctx.ui.notify(`Switched to ${label} (${level})`, "info");
  } else {
    ctx.ui.notify(`Switched to ${label}`, "info");
  }
}

function getThinkingLevelCompletions(
  modelRegistry: ExtensionContext["modelRegistry"] | undefined,
  target: ModelTarget,
  prefix: string,
): AutocompleteItem[] | null {
  const model = modelRegistry?.find(target.provider, target.id);
  const levels = model ? getSupportedThinkingLevels(model) : ALL_LEVELS;
  const matches = levels.filter((level) => level.startsWith(prefix.trimStart()));
  if (matches.length === 0) return null;
  return matches.map((level) => ({ value: level, label: level }));
}

export default function (pi: ExtensionAPI) {
  let modelRegistry: ExtensionContext["modelRegistry"] | undefined;
  pi.on("session_start", (_event, ctx) => {
    modelRegistry = ctx.modelRegistry;
  });

  for (const [alias, target] of Object.entries(ALIASES)) {
    pi.registerCommand(alias, {
      description: `Switch to ${target.provider}/${target.id} [level]`,
      getArgumentCompletions: (prefix) =>
        getThinkingLevelCompletions(modelRegistry, target, prefix),
      handler: (args, ctx) => switchModel(pi, ctx, target, args),
    });
  }
}
