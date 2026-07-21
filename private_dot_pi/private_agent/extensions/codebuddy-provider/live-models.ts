import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { CLI_BASE_URL, DEFAULT_DOMAIN, USER_AGENT, VERSION } from "./constants.js";
import { decodeUserId, ensureSuccess, readHeader, requestJson } from "./utils.js";

const PRODUCT_CONFIG_URL = new URL("/v3/config", CLI_BASE_URL).toString();
const LIVE_MODELS_TIMEOUT_MS = 5000;
const EXCLUDED_MODEL_TAGS = new Set([
  "text-to-image",
  "image-to-image",
  "text-to-video",
  "image-to-video",
]);

type CodebuddyProductConfigResponse = {
  code?: number | string;
  msg?: string;
  data?: {
    models?: CodebuddyProductModel[];
  };
};

type CodebuddyProductModel = {
  id?: string;
  name?: string;
  tags?: string[];
  supportsToolCall?: boolean;
  supportsImages?: boolean;
  supportsReasoning?: boolean;
  maxInputTokens?: number;
  maxOutputTokens?: number;
};

interface FetchLiveModelsOptions {
  accessToken: string;
  modelHeaders?: Record<string, string>;
  signal?: AbortSignal;
}

function buildProductConfigHeaders(
  accessToken: string,
  modelHeaders?: Record<string, string>,
): Record<string, string> {
  const userId = readHeader(modelHeaders, "X-User-Id") || decodeUserId(accessToken);
  const domain = readHeader(modelHeaders, "X-Domain") || DEFAULT_DOMAIN;
  const enterpriseId = readHeader(modelHeaders, "X-Enterprise-Id");
  const department = readHeader(modelHeaders, "X-Department-Info") || "";
  const agentPurpose = readHeader(modelHeaders, "X-Agent-Purpose");

  return {
    Authorization: `Bearer ${accessToken}`,
    ...(userId ? { "X-User-Id": userId } : {}),
    "X-Domain": domain,
    ...(enterpriseId ? { "X-Enterprise-Id": enterpriseId } : {}),
    "X-Department-Info": department,
    "X-IDE-Type": "CLI",
    "X-IDE-Name": "CLI",
    "X-IDE-Version": VERSION,
    "X-Product-Version": VERSION,
    "X-Requested-With": "XMLHttpRequest",
    ...(agentPurpose ? { "X-Agent-Purpose": agentPurpose } : {}),
    "User-Agent": USER_AGENT,
    Connection: "close",
  };
}

function isLiveChatModel(
  model: CodebuddyProductModel,
): model is Required<Pick<CodebuddyProductModel, "id" | "name">> & CodebuddyProductModel {
  if (!model.id || !model.name) return false;
  if (model.supportsToolCall === false) return false;
  const tags = model.tags ?? [];
  return !tags.some((tag) => EXCLUDED_MODEL_TAGS.has(tag));
}

function toProviderModelConfig(
  model: Required<Pick<CodebuddyProductModel, "id" | "name">> & CodebuddyProductModel,
): ProviderModelConfig {
  return {
    id: model.id,
    name: model.name,
    reasoning: Boolean(model.supportsReasoning),
    input: model.supportsImages ? ["text", "image"] : ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: model.maxInputTokens ?? 200000,
    maxTokens: model.maxOutputTokens ?? 32000,
    compat: { supportsDeveloperRole: false, maxTokensField: "max_tokens" },
  };
}

export async function fetchLiveModels({
  accessToken,
  modelHeaders,
  signal,
}: FetchLiveModelsOptions): Promise<ProviderModelConfig[] | null> {
  try {
    const payload = await requestJson<CodebuddyProductConfigResponse>(PRODUCT_CONFIG_URL, {
      headers: buildProductConfigHeaders(accessToken, modelHeaders),
      signal: signal
        ? AbortSignal.any([AbortSignal.timeout(LIVE_MODELS_TIMEOUT_MS), signal])
        : AbortSignal.timeout(LIVE_MODELS_TIMEOUT_MS),
    });

    ensureSuccess(payload, "Failed to fetch CodeBuddy live models");
    const models = payload.data?.models;
    if (!Array.isArray(models)) return null;

    const providerModels = models.filter(isLiveChatModel).map(toProviderModelConfig);
    return providerModels.length > 0 ? providerModels : null;
  } catch {
    return null;
  }
}
