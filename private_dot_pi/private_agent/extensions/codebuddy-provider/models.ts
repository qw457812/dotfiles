import type { AnyModel, Model } from "@earendil-works/pi-ai";
import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { CHAT_BASE_URL, PROVIDER } from "./constants.js";

export type ChatModelConfig = Extract<ProviderModelConfig, { type?: "chat" }>;
export type CodebuddyModel = Model<"openai-completions">;

export function isCodebuddyModel(model: AnyModel): model is CodebuddyModel {
  return (
    (model.type === undefined || model.type === "chat") &&
    model.provider === PROVIDER &&
    model.api === "openai-completions"
  );
}

export function getCodebuddyModelOptions(
  models: readonly AnyModel[],
): { model: CodebuddyModel; label: string }[] {
  const entries = models.filter(isCodebuddyModel).map((model) => {
    const match = /\((x(\d+(?:\.\d+)?)(?: credits)?)\)$/.exec(model.name);
    return {
      model,
      credits: match?.[1] ?? "credits unknown",
      rate: match ? Number(match[2]) : Infinity,
    };
  });
  entries.sort((a, b) => a.rate - b.rate || a.model.id.localeCompare(b.model.id));
  if (entries.length === 0) return [];
  const width = Math.max(...entries.map((entry) => entry.model.id.length));
  return entries.map((entry) => ({
    model: entry.model,
    label: `${entry.model.id.padEnd(width)}  ${entry.credits}`,
  }));
}

export function toCodebuddyModel(config: ChatModelConfig): CodebuddyModel {
  return {
    id: config.id,
    name: config.name,
    api: "openai-completions",
    provider: PROVIDER,
    baseUrl: config.baseUrl ?? CHAT_BASE_URL,
    reasoning: config.reasoning,
    thinkingLevelMap: config.thinkingLevelMap,
    input: config.input,
    cost: config.cost,
    contextWindow: config.contextWindow,
    maxTokens: config.maxTokens,
    headers: config.headers,
    compat: config.compat,
  };
}
