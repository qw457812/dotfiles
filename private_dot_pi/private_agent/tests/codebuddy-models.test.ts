import type { AnyModel } from "@earendil-works/pi-ai";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CHAT_BASE_URL, PROVIDER } from "../extensions/codebuddy-provider/constants.js";
import { fetchLiveModels } from "../extensions/codebuddy-provider/live-models.js";
import {
  type ChatModelConfig,
  isCodebuddyModel,
  toCodebuddyModel,
} from "../extensions/codebuddy-provider/models.js";
import modelsData from "../extensions/codebuddy-provider/models.json" with { type: "json" };

const configs = modelsData as ChatModelConfig[];
const chat = toCodebuddyModel(configs[0]);

afterEach(() => vi.unstubAllGlobals());

describe("CodeBuddy chat models", () => {
  it("preserves static metadata and thinking levels", () => {
    for (const config of configs) {
      expect(toCodebuddyModel(config)).toMatchObject({
        ...config,
        provider: PROVIDER,
        api: "openai-completions",
        baseUrl: CHAT_BASE_URL,
      });
    }
    expect(toCodebuddyModel({ ...configs[0], baseUrl: "https://example.com" }).baseUrl).toBe(
      "https://example.com",
    );
  });

  it("accepts implicit and explicit chat models only for the CodeBuddy API", () => {
    expect(isCodebuddyModel(chat)).toBe(true);
    expect(isCodebuddyModel({ ...chat, type: "chat" })).toBe(true);
    expect(isCodebuddyModel({ ...chat, provider: "other" })).toBe(false);
    expect(isCodebuddyModel({ ...chat, api: "other-chat-api", compat: undefined })).toBe(false);
  });

  it("rejects image and classifier entries even with matching provider and API", () => {
    const mixed: AnyModel[] = [
      chat,
      { ...chat, type: "image", output: ["image"] },
      { ...chat, type: "classifier" },
    ];
    expect(mixed.filter(isCodebuddyModel)).toEqual([chat]);
  });

  it("preserves live-model filtering, agent order and reasoning allowlists", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response(
            JSON.stringify({
              code: 0,
              data: {
                agents: [{ name: "cli", models: ["reasoning", "image", "plain"] }],
                models: [
                  { id: "plain", name: "Plain", supportsReasoning: false },
                  { id: "image", name: "Image", tags: ["text-to-image"] },
                  { id: "no-tools", name: "No tools", supportsToolCall: false },
                  {
                    id: "reasoning",
                    name: "Reasoning",
                    supportsReasoning: true,
                    supportsImages: true,
                    maxInputTokens: 12345,
                    maxOutputTokens: 2345,
                    reasoning: { canDisableThinking: false, supportedEfforts: ["high", "max"] },
                  },
                ],
              },
            }),
          ),
      ),
    );
    const models = await fetchLiveModels({ accessToken: "test-token" });
    expect(models.map((model) => model.id)).toEqual(["reasoning", "plain"]);
    expect(models.every(isCodebuddyModel)).toBe(true);
    expect(models[0]).toMatchObject({
      reasoning: true,
      input: ["text", "image"],
      contextWindow: 12345,
      maxTokens: 2345,
      thinkingLevelMap: {
        off: null,
        minimal: null,
        low: null,
        medium: null,
        high: "high",
        xhigh: null,
        max: "max",
      },
    });
    expect(models[1].thinkingLevelMap).toBeUndefined();
  });
});
