// https://github.com/qjf44/dsh-plugin-thinking-api
// https://github.com/SoulChildTc/pi-codebuddy-oauth

import {
  type ApiKeyAuth,
  type TranscriptContext,
  type Model,
  type OAuthAuth,
  type Provider,
  type ProviderHeaders,
  type SimpleStreamOptions,
  type StreamOptions,
} from "@earendil-works/pi-ai";
import { openAICompletionsApi } from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { codebuddyCredentialsToAuth, loginCodebuddy, refreshCodebuddyCredentials } from "./auth.js";
import { CHAT_BASE_URL, DEFAULT_DOMAIN, PROVIDER, USER_AGENT, VERSION } from "./constants.js";
import { fetchLiveModels } from "./live-models.js";
import {
  type ChatModelConfig,
  type CodebuddyModel,
  getCodebuddyModelOptions,
  isCodebuddyModel,
  parseCodebuddyCredits,
  toCodebuddyModel,
} from "./models.js";
import modelsData from "./models.json" with { type: "json" };
import type { CodebuddyOAuthCredentials } from "./types.js";
import { decodeUserId, readHeader, requestId } from "./utils.js";

// readlink -f ~/.local/bin/codebuddy
// ~/.codebuddy/logs/
// ~/.codebuddy/local_storage/
// pi --list-models codebuddy
const MODELS = (modelsData as ChatModelConfig[]).map(toCodebuddyModel);
const openaiCompletions = openAICompletionsApi();

const apiKeyAuth: ApiKeyAuth = {
  name: "CodeBuddy auth token",
  async resolve({ ctx, credential }) {
    const apiKey = credential?.key ?? (await ctx.env("CODEBUDDY_AUTH_TOKEN"));
    if (!apiKey) return undefined;
    return {
      auth: { apiKey },
      env: credential?.env,
      source: credential?.key ? "stored credential" : "CODEBUDDY_AUTH_TOKEN",
    };
  },
};

const oauthAuth: OAuthAuth = {
  name: "CodeBuddy CN",
  login: loginCodebuddy,
  refresh: refreshCodebuddyCredentials,
  async toAuth(credentials) {
    return codebuddyCredentialsToAuth(credentials as CodebuddyOAuthCredentials);
  },
};

function buildRequestHeaders(
  model: CodebuddyModel,
  options: StreamOptions | SimpleStreamOptions | undefined,
  conversationId: string,
): ProviderHeaders {
  const sourceHeaders: ProviderHeaders = { ...model.headers, ...options?.headers };
  const accessToken = options?.apiKey;
  const userId = readHeader(sourceHeaders, "X-User-Id") || decodeUserId(accessToken);
  const domain = readHeader(sourceHeaders, "X-Domain") || DEFAULT_DOMAIN;
  const enterpriseId = readHeader(sourceHeaders, "X-Enterprise-Id");
  const department = readHeader(sourceHeaders, "X-Department-Info") || "";
  const agentPurpose = readHeader(sourceHeaders, "X-Agent-Purpose");
  const conversationRequestId = requestId();
  const conversationMessageId = requestId();

  return {
    ...(userId ? { "X-User-Id": userId } : {}),
    "X-Domain": domain,
    ...(enterpriseId ? { "X-Enterprise-Id": enterpriseId } : {}),
    "X-Department-Info": department,
    "X-IDE-Type": "CLI",
    "X-IDE-Name": "CLI",
    "X-IDE-Version": VERSION,
    "X-Product-Version": VERSION,
    "X-Requested-With": "XMLHttpRequest",
    "X-Conversation-ID": conversationId,
    "X-Conversation-Request-ID": conversationRequestId,
    "X-Conversation-Message-ID": conversationMessageId,
    "X-Request-ID": conversationMessageId,
    "X-Agent-Intent": "craft",
    ...(agentPurpose ? { "X-Agent-Purpose": agentPurpose } : {}),
    "User-Agent": USER_AGENT,
    ...options?.headers,
  };
}

function prepareRequest<T extends StreamOptions | SimpleStreamOptions>(
  model: Model<"openai-completions">,
  options: T | undefined,
  conversationId: string,
): { model: CodebuddyModel; options: T } {
  if (!options?.apiKey) {
    throw new Error("CodeBuddy access token not found. Please run /login codebuddy first");
  }

  const codebuddyModel = {
    ...model,
    baseUrl: model.baseUrl || CHAT_BASE_URL,
  } as CodebuddyModel;
  return {
    model: codebuddyModel,
    options: {
      ...options,
      headers: buildRequestHeaders(codebuddyModel, options, conversationId),
    } as T,
  };
}

function createCodebuddyProvider(
  conversationIdFor: (sessionId: string | undefined) => string,
  onModelsChanged: (models: readonly CodebuddyModel[]) => void,
): Provider<"openai-completions"> {
  let models: readonly CodebuddyModel[] = MODELS;

  function updateModels(next: readonly CodebuddyModel[]) {
    models = next;
    onModelsChanged(models);
  }

  return {
    id: PROVIDER,
    name: "CodeBuddy CN",
    baseUrl: CHAT_BASE_URL,
    auth: { apiKey: apiKeyAuth, oauth: oauthAuth },
    getModels: () => models,
    async refreshModels(context) {
      const cachedModels = context.stored?.models.filter(isCodebuddyModel);
      if (
        cachedModels?.length &&
        !(await context.publish({ update: () => updateModels(cachedModels) }))
      ) {
        return;
      }

      if (!context.allowNetwork || context.signal.aborted || !context.credential) return;

      const auth =
        context.credential.type === "oauth"
          ? codebuddyCredentialsToAuth(context.credential as CodebuddyOAuthCredentials)
          : { apiKey: context.credential.key };
      if (!auth.apiKey) return;

      const liveModels = await fetchLiveModels({
        accessToken: auth.apiKey,
        modelHeaders: auth.headers,
        signal: context.signal,
      });
      if (context.signal.aborted) return;

      await context.publish({
        persist: { models: liveModels, checkedAt: Date.now() },
        update: () => updateModels(liveModels),
      });
    },
    stream(model, context: TranscriptContext, options?: StreamOptions) {
      const request = prepareRequest(model, options, conversationIdFor(options?.sessionId));
      return openaiCompletions.stream(request.model, context, request.options);
    },
    streamSimple(model, context: TranscriptContext, options?: SimpleStreamOptions) {
      const request = prepareRequest(model, options, conversationIdFor(options?.sessionId));
      return openaiCompletions.streamSimple(request.model, context, request.options);
    },
  };
}

function updateCreditsStatus(model: ExtensionContext["model"], ctx: ExtensionContext) {
  if (!ctx.hasUI) return;
  const multiplier =
    model && isCodebuddyModel(model) ? parseCodebuddyCredits(model.name)?.multiplier : undefined;
  ctx.ui.setStatus(
    "codebuddy-model-credits",
    multiplier ? ctx.ui.theme.fg("dim", multiplier) : undefined,
  );
}

export default function (pi: ExtensionAPI) {
  // Stable X-Conversation-ID per pi session, mirroring the official CLI. Note this is
  // determinism, not a cache win: repeat requests still report cached_tokens: 0.
  const CONVERSATION_ID_CACHE_MAX = 100;
  const conversationIds = new Map<string, string>(); // sessionId → id, oldest first

  function conversationIdFor(sessionId: string | undefined): string {
    if (!sessionId) return requestId();
    const existing = conversationIds.get(sessionId);
    if (existing) return existing;
    const id = requestId();
    conversationIds.set(sessionId, id);
    if (conversationIds.size > CONVERSATION_ID_CACHE_MAX) {
      const oldest = conversationIds.keys().next();
      if (!oldest.done) conversationIds.delete(oldest.value);
    }
    return id;
  }

  let catalog: readonly CodebuddyModel[] | undefined;
  let currentCtx: ExtensionContext | undefined;

  function refreshCreditsStatus() {
    if (!currentCtx) return;
    // Catalog publication does not replace the session's selected model object.
    let model = currentCtx.model;
    if (model && isCodebuddyModel(model) && catalog) {
      const modelId = model.id;
      model = catalog.find((entry) => entry.id === modelId);
    }
    updateCreditsStatus(model, currentCtx);
  }

  pi.registerProvider(
    createCodebuddyProvider(conversationIdFor, (models) => {
      catalog = models;
      refreshCreditsStatus();
    }),
  );

  pi.on("session_start", (_event, ctx) => {
    currentCtx = ctx;
    refreshCreditsStatus();
  });
  pi.on("model_select", () => refreshCreditsStatus());
  pi.on("session_shutdown", () => {
    currentCtx = undefined;
  });

  pi.registerCommand("codebuddy-models", {
    description: "Select a CodeBuddy model by credits (lowest first)",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) return;

      const options = getCodebuddyModelOptions(ctx.modelRegistry.getAll());
      if (options.length === 0) {
        ctx.ui.notify("No CodeBuddy models available.", "warning");
        return;
      }

      const selected = await ctx.ui.select(
        "Select CodeBuddy model (lowest credits first)",
        options.map((option) => option.label),
      );
      const option = options.find((option) => option.label === selected);
      if (!option) return;

      if (!(await pi.setModel(option.model))) {
        ctx.ui.notify(
          "CodeBuddy credentials unavailable. Please run /login codebuddy first.",
          "error",
        );
        return;
      }
      ctx.ui.notify(`Switched to ${PROVIDER}/${option.model.id}`, "info");
    },
  });

  // Compaction rewrites the history behind the id, so don't reuse it afterwards.
  pi.on("session_before_compact", (_event, ctx) => {
    const sessionId = ctx.sessionManager.getSessionId();
    if (sessionId) conversationIds.delete(sessionId);
  });
}
