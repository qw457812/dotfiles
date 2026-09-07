/**
 * model-shortcuts.ts - quick model switch commands
 *
 *   /<alias> [level]  e.g. /sol high
 *
 * Precedence: explicit level > thinking.ts > `modelThinkingLevels` > global defaults.
 * https://github.com/qw457812/dotfiles/blob/62b8a18ab1d75c6a52857d2a47be59a508c7f42c/private_dot_pi/private_agent/extensions/thinking.ts
 */
import { getSupportedThinkingLevels, type ModelThinkingLevel } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

const ALIASES: Record<string, ModelTarget | readonly ModelTarget[]> = {
  astra: { provider: "openai-codex", id: "gpt-6-astra" },
  sol: { provider: "openai-codex", id: "gpt-5.6-sol" },
  terra: { provider: "openai-codex", id: "gpt-5.6-terra" },
  luna: { provider: "openai-codex", id: "gpt-5.6-luna" },
  kimi: [
    { provider: "commandcode", id: "moonshotai/Kimi-K3" },
    { provider: "neuralwatt", id: "kimi-k3" },
  ],
  glm: [
    { provider: "commandcode", id: "zai-org/GLM-5.3" },
    { provider: "neuralwatt", id: "glm-5.3" },
    { provider: "codebuddy", id: "glm-5.3" },
  ],
  glmflash: [
    { provider: "neuralwatt", id: "glm-5.3-flash" },
    { provider: "commandcode", id: "z-ai/glm-5.3-flash" },
    { provider: "hyper", id: "glm-5.3-flash" },
    { provider: "codebuddy", id: "glm-5.3-flash" },
  ],
  ds: { provider: "commandcode", id: "deepseek/deepseek-v4-pro" },
  dsflash: [
    { provider: "neuralwatt", id: "deepseek-v4-flash" },
    { provider: "commandcode", id: "deepseek/deepseek-v4-flash" },
  ],
  qwen: [
    { provider: "commandcode", id: "Qwen/Qwen3.8-Max-0902" },
    { provider: "commandcode", id: "Qwen/Qwen3.8-27B" },
    { provider: "neuralwatt", id: "qwen-3.8-27b" },
  ],
  qwenflash: [
    { provider: "commandcode", id: "Qwen/Qwen3.8-Flash" },
    { provider: "hyper", id: "qwen3.8-flash" },
  ],
  mimo: { provider: "commandcode", id: "xiaomi/mimo-v2.5-pro" },
  flex: { provider: "neuralwatt", id: "kimi-k3-flex" },
  cmd: { provider: "commandcode", id: "z-ai/glm-5.3-flash" },
  hyper: { provider: "hyper", id: "glm-5.3-flash" },
  buddy: { provider: "codebuddy", id: "glm-5.3-flash" },
  coral: { provider: "coralbricks", id: "glm-5.3-fp4" },
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

async function selectModel(
  ctx: ExtensionCommandContext,
  alias: string,
  targets: readonly ModelTarget[],
): Promise<ModelTarget | undefined> {
  if (targets.length === 1) return targets[0];

  const selected = await ctx.ui.select(
    `Select /${alias} model`,
    targets.map((target) => `${target.provider}/${target.id}`),
  );
  return targets.find((target) => `${target.provider}/${target.id}` === selected);
}

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

  const arg = args.trim();
  const level = arg ? (arg as ModelThinkingLevel) : undefined;
  if (level && !ALL_LEVELS.includes(level)) {
    ctx.ui.notify(`Invalid thinking level "${arg}". Valid: ${ALL_LEVELS.join(", ")}`, "error");
    return;
  }

  // setModel awaits model_select handlers (e.g. thinking.ts auto-level, /settings `modelThinkingLevels`),
  // so applying the requested level afterwards takes precedence.
  if (!(await pi.setModel(model))) {
    ctx.ui.notify(`No API key for ${label}`, "error");
    return;
  }

  if (level) {
    pi.setThinkingLevel(level);
    const effectiveLevel = pi.getThinkingLevel();
    const levelLabel = effectiveLevel === level ? level : `${level} -> ${effectiveLevel}, clamped`;
    ctx.ui.notify(`Switched to ${label} (${levelLabel})`, "info");
  } else {
    ctx.ui.notify(`Switched to ${label}`, "info");
  }
}

function getThinkingLevelCompletions(
  modelRegistry: ExtensionContext["modelRegistry"] | undefined,
  targets: readonly ModelTarget[],
  prefix: string,
): AutocompleteItem[] | null {
  const levels = new Set<ModelThinkingLevel>();
  for (const target of targets) {
    const model = modelRegistry?.find(target.provider, target.id);
    for (const level of model ? getSupportedThinkingLevels(model) : ALL_LEVELS) {
      levels.add(level);
    }
  }

  const completions = ALL_LEVELS.filter(
    (level) => levels.has(level) && level.startsWith(prefix.trimStart()),
  );
  if (completions.length === 0) return null;
  return completions.map((level) => ({ value: level, label: level }));
}

export default function (pi: ExtensionAPI) {
  let modelRegistry: ExtensionContext["modelRegistry"] | undefined;
  pi.on("session_start", (_event, ctx) => {
    modelRegistry = ctx.modelRegistry;
  });

  for (const [alias, configuredTargets] of Object.entries(ALIASES)) {
    const targets = "provider" in configuredTargets ? [configuredTargets] : configuredTargets;
    const labels = targets.map((target) => `${target.provider}/${target.id}`);
    pi.registerCommand(alias, {
      description:
        targets.length === 1
          ? `Switch to ${labels[0]} [level]`
          : `Select model (${labels.join(", ")}) [level]`,
      getArgumentCompletions: (prefix) =>
        getThinkingLevelCompletions(modelRegistry, targets, prefix),
      handler: async (args, ctx) => {
        const target = await selectModel(ctx, alias, targets);
        if (target) await switchModel(pi, ctx, target, args);
      },
    });
  }
}
