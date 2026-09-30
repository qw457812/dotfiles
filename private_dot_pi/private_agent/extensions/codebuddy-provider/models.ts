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
