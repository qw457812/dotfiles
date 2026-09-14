import type { ProviderHeaders } from "@earendil-works/pi-ai";
import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { CLI_BASE_URL, DEFAULT_DOMAIN, USER_AGENT, VERSION } from "./constants.js";
import { type CodebuddyModel, toCodebuddyModel } from "./models.js";
import { decodeUserId, ensureSuccess, readHeader, requestJson } from "./utils.js";

const PRODUCT_CONFIG_URL = new URL("/v3/config", CLI_BASE_URL).toString();
const LIVE_MODELS_TIMEOUT_MS = 5000;
const EXCLUDED_MODEL_TAGS = new Set([
  "text-to-image",
  "image-to-image",
  "text-to-video",
  "image-to-video",
]);

/** pi-ai thinking levels, ascending. Mirrors pi-ai `EXTENDED_THINKING_LEVELS`. */
const PI_THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

type ThinkingLevelMap = NonNullable<ProviderModelConfig["thinkingLevelMap"]>;

type CodebuddyProductConfigResponse = {
  code?: number | string;
  msg?: string;
  data?: {
    models?: CodebuddyProductModel[];
    agents?: CodebuddyAgent[];
  };
};

type CodebuddyAgent = {
  name?: string;
  /** Model ids this agent exposes, in picker order. */
  models?: string[];
  tags?: string[];
  modelTags?: string[];
};

type CodebuddyReasoningConfig = {
  /** Whether the gateway lets this model run with thinking turned off. */
  canDisableThinking?: boolean;
  /** Level the gateway uses when the request does not name one. */
  defaultEffort?: string;
  /** Authoritative per-model `reasoning_effort` allowlist. */
  supportedEfforts?: string[];
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
  canDisableThinking?: boolean;
  reasoning?: CodebuddyReasoningConfig;
};

interface FetchLiveModelsOptions {
  accessToken: string;
  modelHeaders?: ProviderHeaders;
  signal?: AbortSignal;
}

function buildProductConfigHeaders(
  accessToken: string,
  modelHeaders?: ProviderHeaders,
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

/**
 * Pick the agent whose model allowlist the official CodeBuddy CLI exposes.
 *
 * The CLI's `AgentModelResolver` resolves an agent's `models` ids against the
 * catalogue; for the CLI agent that yields exactly the list its `--model` flag
 * advertises (14 ids today), not the whole catalogue. The agent is named `cli`
 * in current configs — `craft` is an `X-Agent-Intent` header value and a
 * `model:craft` tag, not the agent name — so match the name first and fall back
 * to tags, then to the first agent that declares any models.
 *
 * Returns [] when the response carries no agent allowlist, which callers treat
 * as "do not scope" rather than "no models".
 */
function resolveAgentModelIds(agents: CodebuddyAgent[] | undefined): string[] {
  if (!Array.isArray(agents) || agents.length === 0) return [];
  const hasModels = (agent: CodebuddyAgent | undefined): agent is CodebuddyAgent =>
    Boolean(agent?.models?.length);
  const byName = (name: string) => agents.find((a) => a.name === name && a.models?.length);
  const byTag = (tag: string) =>
    agents.find((a) => a.models?.length && (a.tags ?? []).includes(tag));

  const agent =
    byName("cli") ??
    byName("craft") ??
    byTag("model:craft") ??
    byTag("default") ??
    agents.find(hasModels);
  return agent?.models ?? [];
}

/**
 * Build the pi-ai `thinkingLevelMap` from the gateway's own effort metadata.
 *
 * Conservative on purpose: only levels the gateway explicitly declared are
 * advertised, mirroring the official CodeBuddy CLI. Its `withSupportedEffortsFallback`
 * builds `{[effort]: effort}` from `reasoning.supportedEfforts` and adds nothing
 * when that list is absent. pi-ai treats `xhigh`/`max` as opt-in (they exist only
 * when the map names them), so an absent allowlist leaves them hidden rather than
 * guessed — the gateway does accept those values today, but `supportedEfforts` is
 * the vendor's explicit declaration and the safer default.
 *
 * pi-ai semantics: `null` marks a level unsupported, an absent entry leaves it
 * supported with the level name as the wire value.
 */
function buildThinkingLevelMap(model: CodebuddyProductModel): ThinkingLevelMap | undefined {
  const supported = (model.reasoning?.supportedEfforts ?? []).filter(
    (effort) => typeof effort === "string" && effort.length > 0,
  );
  const canDisable = model.canDisableThinking ?? model.reasoning?.canDisableThinking;

  // No declared allowlist: fall back to pi-ai's defaults (off/minimal/low/medium/high).
  // An absent `off` key keeps pi-ai's `thinking:{type:"disabled"}` path working.
  if (supported.length === 0) {
    return canDisable === false ? { off: null } : undefined;
  }

  const map: ThinkingLevelMap = {};
  for (const level of PI_THINKING_LEVELS) {
    if (level === "off") {
      if (canDisable === false) map.off = null;
      continue;
    }
    map[level] = supported.includes(level) ? level : null;
  }
  return map;
}

function toLiveModel(
  model: Required<Pick<CodebuddyProductModel, "id" | "name">> & CodebuddyProductModel,
): CodebuddyModel {
  const reasoning = Boolean(model.supportsReasoning);
  const config: ProviderModelConfig = {
    id: model.id,
    name: model.name,
    reasoning,
    thinkingLevelMap: reasoning ? buildThinkingLevelMap(model) : undefined,
    input: model.supportsImages ? ["text", "image"] : ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: model.maxInputTokens ?? 200000,
    maxTokens: model.maxOutputTokens ?? 32000,
    compat: {
      supportsDeveloperRole: false,
      supportsReasoningEffort: true,
      maxTokensField: "max_tokens",
      thinkingFormat: "deepseek",
    },
  };
  return toCodebuddyModel(config);
}

export async function fetchLiveModels({
  accessToken,
  modelHeaders,
  signal,
}: FetchLiveModelsOptions): Promise<CodebuddyModel[]> {
  const payload = await requestJson<CodebuddyProductConfigResponse>(PRODUCT_CONFIG_URL, {
    headers: buildProductConfigHeaders(accessToken, modelHeaders),
    signal: signal
      ? AbortSignal.any([AbortSignal.timeout(LIVE_MODELS_TIMEOUT_MS), signal])
      : AbortSignal.timeout(LIVE_MODELS_TIMEOUT_MS),
  });

  ensureSuccess(payload, "Failed to fetch CodeBuddy live models");
  const models = payload.data?.models;
  if (!Array.isArray(models)) {
    throw new Error("CodeBuddy model response is missing models");
  }

  const chatModels = models.filter(isLiveChatModel);

  // Scope to the agent's allowlist, keeping its declared order. Unknown ids are
  // dropped; an empty result means the allowlist is stale, so fall back to the
  // full chat catalogue rather than reporting "no supported models".
  const available = new Map(chatModels.map((model) => [model.id, model]));
  const scoped: typeof chatModels = [];
  const seen = new Set<string>();
  for (const id of resolveAgentModelIds(payload.data?.agents)) {
    const model = available.get(id);
    if (!model || seen.has(id)) continue;
    seen.add(id);
    scoped.push(model);
  }

  const providerModels = (scoped.length > 0 ? scoped : chatModels).map(toLiveModel);
  if (providerModels.length === 0) {
    throw new Error("CodeBuddy returned no supported chat models");
  }
  return providerModels;
}
