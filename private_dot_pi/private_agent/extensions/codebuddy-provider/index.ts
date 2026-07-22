import {
  type Api,
  type ApiKeyAuth,
  type Context,
  type Model,
  type OAuthAuth,
  type Provider,
  type ProviderHeaders,
  type SimpleStreamOptions,
  type StreamOptions,
} from "@earendil-works/pi-ai";
import { openAICompletionsApi } from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { codebuddyCredentialsToAuth, loginCodebuddy, refreshCodebuddyCredentials } from "./auth.js";
import { CHAT_BASE_URL, DEFAULT_DOMAIN, PROVIDER, USER_AGENT, VERSION } from "./constants.js";
import { fetchLiveModels } from "./live-models.js";
import { type CodebuddyModel, toCodebuddyModel } from "./models.js";
import modelsData from "./models.json" with { type: "json" };
import type { CodebuddyOAuthCredentials } from "./types.js";
import { decodeUserId, readHeader, requestId } from "./utils.js";

// $(npm root -g)/@tencent-ai/codebuddy-code/product.internal.json
// ~/.codebuddy/logs/
// ~/.codebuddy/local_storage/
// pi --list-models codebuddy
const MODELS = (modelsData as ProviderModelConfig[]).map(toCodebuddyModel);
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
): ProviderHeaders {
  const sourceHeaders: ProviderHeaders = { ...model.headers, ...options?.headers };
  const accessToken = options?.apiKey;
  const userId = readHeader(sourceHeaders, "X-User-Id") || decodeUserId(accessToken);
  const domain = readHeader(sourceHeaders, "X-Domain") || DEFAULT_DOMAIN;
  const enterpriseId = readHeader(sourceHeaders, "X-Enterprise-Id");
  const department = readHeader(sourceHeaders, "X-Department-Info") || "";
  const agentPurpose = readHeader(sourceHeaders, "X-Agent-Purpose");
  const conversationId = requestId();
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
      headers: buildRequestHeaders(codebuddyModel, options),
    } as T,
  };
}

function isCodebuddyModel(model: Model<Api>): model is CodebuddyModel {
  return model.provider === PROVIDER && model.api === "openai-completions";
}

function createCodebuddyProvider(): Provider<"openai-completions"> {
  let models: readonly CodebuddyModel[] = MODELS;
  let inflightRefresh: Promise<void> | undefined;

  return {
    id: PROVIDER,
    name: "CodeBuddy CN",
    baseUrl: CHAT_BASE_URL,
    auth: { apiKey: apiKeyAuth, oauth: oauthAuth },
    getModels: () => models,
    refreshModels(context) {
      inflightRefresh ??= (async () => {
        try {
          const stored = await context.store.read();
          const cachedModels = stored?.models.filter(isCodebuddyModel);
          if (cachedModels?.length) models = cachedModels;

          if (!context.allowNetwork || context.signal?.aborted || !context.credential) return;

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
          if (context.signal?.aborted) return;

          models = liveModels;
          await context.store.write({ models: liveModels, checkedAt: Date.now() });
        } finally {
          inflightRefresh = undefined;
        }
      })();
      return inflightRefresh;
    },
    stream(model, context: Context, options?: StreamOptions) {
      const request = prepareRequest(model, options);
      return openaiCompletions.stream(request.model, context, request.options);
    },
    streamSimple(model, context: Context, options?: SimpleStreamOptions) {
      const request = prepareRequest(model, options);
      return openaiCompletions.streamSimple(request.model, context, request.options);
    },
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerProvider(createCodebuddyProvider());
}
