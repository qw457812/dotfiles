import {
  type Api,
  type AssistantMessageEventStream,
  type Context,
  type Model,
  type SimpleStreamOptions,
  streamSimpleOpenAICompletions,
} from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { loginCodebuddy, refreshCodebuddyCredentials } from "./auth.js";
import { CHAT_BASE_URL, DEFAULT_DOMAIN, PROVIDER, USER_AGENT, VERSION } from "./constants.js";
import modelsData from "./models.json" with { type: "json" };
import type { CodebuddyOAuthCredentials } from "./types.js";
import { decodeUserId, firstNonEmpty, normalizeDomain, readHeader, requestId } from "./utils.js";

const MODELS: ProviderModelConfig[] = modelsData as ProviderModelConfig[];

function streamCodebuddy(
  model: Model<Api>,
  context: Context,
  options?: SimpleStreamOptions,
): AssistantMessageEventStream {
  const accessToken = options?.apiKey;
  if (!accessToken) {
    throw new Error("CodeBuddy access token not found. Please run /login codebuddy first");
  }

  const userId = readHeader(model.headers, "X-User-Id") || decodeUserId(accessToken);
  const domain = readHeader(model.headers, "X-Domain") || DEFAULT_DOMAIN;
  const enterpriseId = readHeader(model.headers, "X-Enterprise-Id");
  const department = readHeader(model.headers, "X-Department-Info") || "";
  const agentPurpose = readHeader(model.headers, "X-Agent-Purpose");
  const conversationId = requestId();
  const conversationRequestId = requestId();
  const conversationMessageId = requestId();

  const headers: Record<string, string> = {
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

  const modelWithBaseUrl = {
    ...(model as Model<"openai-completions">),
    baseUrl: model.baseUrl || CHAT_BASE_URL,
  } as Model<"openai-completions">;

  return streamSimpleOpenAICompletions(modelWithBaseUrl, context, {
    ...options,
    apiKey: accessToken,
    headers,
  });
}

export default function (pi: ExtensionAPI) {
  pi.registerProvider(PROVIDER, {
    name: "CodeBuddy CN",
    baseUrl: CHAT_BASE_URL,
    apiKey: "$CODEBUDDY_AUTH_TOKEN",
    api: "openai-completions",
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
        const userId = firstNonEmpty(c.userId, c.uid) || decodeUserId(c.access);
        const domain = normalizeDomain(c.domain);
        const headers: Record<string, string> = {
          ...(userId ? { "X-User-Id": userId } : {}),
          "X-Domain": domain,
          ...(c.enterpriseId ? { "X-Enterprise-Id": c.enterpriseId } : {}),
        };
        if (c.departmentFullName) {
          headers["X-Department-Info"] = c.departmentFullName;
        }
        return models.map((model) => {
          if (model.provider !== PROVIDER) {
            return model;
          }
          return {
            ...model,
            headers: {
              ...model.headers,
              ...headers,
            },
          };
        });
      },
    },
    streamSimple: streamCodebuddy,
  });
}
