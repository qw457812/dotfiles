import {
  type Api,
  type AssistantMessage,
  type AssistantMessageEventStream,
  type Context,
  createAssistantMessageEventStream,
  type Model,
  type SimpleStreamOptions,
  streamSimpleOpenAICompletions,
} from "@earendil-works/pi-ai";
import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { loginCodebuddy, refreshCodebuddyCredentials } from "./auth.js";
import {
  CODEBUDDY_CHAT_BASE_URL,
  CODEBUDDY_DEFAULT_DOMAIN,
  CODEBUDDY_PRODUCT,
  CODEBUDDY_PROVIDER,
  CODEBUDDY_USER_AGENT,
  CODEBUDDY_VERSION,
} from "./constants.js";
import type { CodebuddyOAuthCredentials } from "./types.js";
import {
  decodeCodebuddyUserId,
  normalizeDomain,
  readHeader,
  requestId,
  stainlessOs,
  firstNonEmpty,
} from "./utils.js";
import modelsData from "./models.json" with { type: "json" };

const MODELS: ProviderModelConfig[] = modelsData as ProviderModelConfig[];

export function streamCodebuddy(
  model: Model<Api>,
  context: Context,
  options?: SimpleStreamOptions,
): AssistantMessageEventStream {
  const stream = createAssistantMessageEventStream();

  (async () => {
    try {
      const accessToken = options?.apiKey;
      if (!accessToken) {
        throw new Error("CodeBuddy access token not found. Please run /login codebuddy first");
      }

      const chatUserId =
        readHeader(model.headers, "X-User-Id") || decodeCodebuddyUserId(accessToken);
      const chatDomain = readHeader(model.headers, "X-Domain") || CODEBUDDY_DEFAULT_DOMAIN;
      const conversationId = requestId();
      const chatRequest = requestId();
      const chatMessage = requestId();

      const headers = {
        ...(chatUserId ? { "X-User-Id": chatUserId } : {}),
        "X-Domain": chatDomain,
        "X-Product": CODEBUDDY_PRODUCT,
        "X-IDE-Type": "CLI",
        "X-IDE-Name": "CLI",
        "X-IDE-Version": CODEBUDDY_VERSION,
        "X-Product-Version": CODEBUDDY_VERSION,
        "X-Requested-With": "XMLHttpRequest",
        "X-Conversation-ID": conversationId,
        "X-Conversation-Request-ID": chatRequest,
        "X-Conversation-Message-ID": chatMessage,
        "X-Request-ID": chatMessage,
        "X-Agent-Intent": "craft",
        "X-Agent-Purpose": "conversation",
        "X-Stainless-Lang": "js",
        "X-Stainless-Package-Version": "6.25.0",
        "X-Stainless-OS": stainlessOs(),
        "X-Stainless-Arch": process.arch,
        "X-Stainless-Runtime": "node",
        "X-Stainless-Runtime-Version": process.version,
        "User-Agent": CODEBUDDY_USER_AGENT,
        ...options?.headers,
      };
      const modelWithBaseUrl = {
        ...(model as Model<"openai-completions">),
        baseUrl: model.baseUrl || CODEBUDDY_CHAT_BASE_URL,
      } as Model<"openai-completions">;

      const innerStream = streamSimpleOpenAICompletions(modelWithBaseUrl, context, {
        ...options,
        apiKey: accessToken,
        headers,
      });

      for await (const event of innerStream) {
        stream.push(event);
      }
      stream.end();
    } catch (error) {
      stream.push({
        type: "error",
        reason: "error",
        error: createErrorMessage(model, error),
      });
      stream.end();
    }
  })();

  return stream;
}

function createErrorMessage(model: Model<Api>, error: unknown): AssistantMessage {
  return {
    role: "assistant",
    content: [],
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "error",
    errorMessage: error instanceof Error ? error.message : String(error),
    timestamp: Date.now(),
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerProvider(CODEBUDDY_PROVIDER, {
    name: "CodeBuddy CN",
    baseUrl: CODEBUDDY_CHAT_BASE_URL,
    apiKey: "CODEBUDDY_AUTH_TOKEN",
    api: "codebuddy-openai-completions",
    models: MODELS,
    oauth: {
      name: "CodeBuddy CN",
      login: loginCodebuddy,
      refreshToken: refreshCodebuddyCredentials,
      getApiKey(credentials) {
        return (credentials as CodebuddyOAuthCredentials).access;
      },
      modifyModels(models, credentials) {
        const c = credentials as CodebuddyOAuthCredentials;
        const modelUserId = firstNonEmpty(c.userId, c.uid) || decodeCodebuddyUserId(c.access);
        const modelDomain = normalizeDomain(c.domain);
        const modelHeaders: Record<string, string> = {
          ...(modelUserId ? { "X-User-Id": modelUserId } : {}),
          "X-Domain": modelDomain,
        };
        return models.map((model) => {
          if (model.provider !== CODEBUDDY_PROVIDER) {
            return model;
          }
          return {
            ...model,
            headers: {
              ...model.headers,
              ...modelHeaders,
            },
          };
        });
      },
    },
    streamSimple: streamCodebuddy,
  });
}
