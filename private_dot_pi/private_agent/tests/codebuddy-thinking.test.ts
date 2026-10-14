import {
  type Provider,
  type SimpleStreamOptions,
  clampThinkingLevel,
  getSupportedThinkingLevels,
  normalizeContext,
} from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { afterEach, describe, expect, it, vi } from "vitest";
import register from "../extensions/codebuddy-provider/index.js";
import { fetchLiveModels } from "../extensions/codebuddy-provider/live-models.js";
import {
  type ChatModelConfig,
  type CodebuddyModel,
  toCodebuddyModel,
} from "../extensions/codebuddy-provider/models.js";
import modelsData from "../extensions/codebuddy-provider/models.json" with { type: "json" };

const levels = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;
type ThinkingLevel = (typeof levels)[number];

// Sanitized capability fields observed in /v3/config for CodeBuddy 2.164.0.
// No credentials or account data; these tests never contact the service.
const catalog = [
  {
    id: "deepseek-v4.1-flash",
    maxOutputTokens: 128000,
    reasoning: {
      canDisableThinking: true,
      defaultEffort: "high",
      supportedEfforts: ["low", "high", "max"],
    },
  },
  {
    id: "glm-5.3-flash",
    maxOutputTokens: 131072,
    reasoning: {
      canDisableThinking: false,
      defaultEffort: "high",
      supportedEfforts: ["low", "high", "max"],
    },
  },
  { id: "glm-5.3", maxOutputTokens: 64000, reasoning: { effort: "medium" } },
  { id: "hy3", maxOutputTokens: 64000, reasoning: { effort: "high" } },
  {
    id: "hy4-preview",
    maxOutputTokens: 64000,
    reasoning: { canDisableThinking: false, defaultEffort: "high", supportedEfforts: ["high"] },
  },
  {
    id: "step-5-preview",
    maxOutputTokens: 64000,
    reasoning: {
      canDisableThinking: false,
      defaultEffort: "high",
      supportedEfforts: ["low", "medium", "high"],
    },
  },
  {
    id: "space-bunny",
    maxOutputTokens: 128000,
    reasoning: {
      canDisableThinking: false,
      defaultEffort: "max",
      supportedEfforts: ["low", "medium", "high", "xhigh", "max"],
    },
  },
].map((model) => ({
  ...model,
  name: model.id,
  supportsReasoning: true,
  supportsImages: true,
  onlyReasoning: true,
  maxInputTokens: model.id === "hy3" ? 192000 : model.id === "hy4-preview" ? 960000 : 1000000,
}));

const expectedEfforts: Record<string, readonly ThinkingLevel[]> = {
  "deepseek-v4.1-flash": ["low", "low", "low", "high", "high", "max", "max"],
  "glm-5.3-flash": ["low", "low", "low", "high", "high", "max", "max"],
  "glm-5.3": ["minimal", "minimal", "low", "medium", "high", "high", "high"],
  hy3: ["minimal", "minimal", "low", "medium", "high", "high", "high"],
  "hy4-preview": ["high", "high", "high", "high", "high", "high", "high"],
  "step-5-preview": ["low", "low", "low", "medium", "high", "high", "high"],
  "space-bunny": ["low", "low", "low", "medium", "high", "xhigh", "max"],
};

const context = normalizeContext({
  messages: [{ role: "user", content: "Say OK", timestamp: 0 }],
});

function createProvider(): Provider<"openai-completions"> {
  const pi = { registerProvider: vi.fn(), registerCommand: vi.fn(), on: vi.fn() };
  register(pi as unknown as ExtensionAPI);
  return pi.registerProvider.mock.calls[0][0];
}

async function liveModels() {
  const fetch = vi.fn(
    async () => new Response(JSON.stringify({ code: 0, data: { models: catalog } })),
  );
  vi.stubGlobal("fetch", fetch);
  const models = await fetchLiveModels({ accessToken: "test-token" });
  expect(fetch).toHaveBeenCalledTimes(1);
  return models;
}

async function capturePayload(
  model: CodebuddyModel,
  reasoning?: ThinkingLevel,
  raw = false,
): Promise<Record<string, unknown>> {
  const fetch = vi.fn(() => {
    throw new Error("Unexpected model network request");
  });
  vi.stubGlobal("fetch", fetch);
  let payload: Record<string, unknown> | undefined;
  const stop = "Stop after local payload capture";
  const options = {
    apiKey: "test-token",
    maxTokens: 32,
    maxRetries: 0,
    onPayload: (value: unknown) => {
      payload = value as Record<string, unknown>;
      throw new Error(stop);
    },
  };
  const provider = createProvider();
  // Pi clamps the UI's off level before streaming; SimpleStreamOptions encodes
  // an allowed off as an absent reasoning option, not the literal "off".
  const effective = reasoning === "off" ? clampThinkingLevel(model, reasoning) : reasoning;
  const simpleOptions: SimpleStreamOptions = {
    ...options,
    ...(effective && effective !== "off" ? { reasoning: effective } : {}),
  };
  const stream = raw
    ? provider.stream(model, context, options)
    : provider.streamSimple(model, context, simpleOptions);
  const result = await stream.result();
  expect(result.stopReason).toBe("error");
  expect(result.errorMessage).toContain(stop);
  expect(fetch).not.toHaveBeenCalled();
  expect(payload).toBeDefined();
  return payload!;
}

afterEach(() => vi.unstubAllGlobals());

describe("CodeBuddy static capability snapshot", () => {
  it("matches the live capabilities of every fallback model", async () => {
    const live = await liveModels();
    for (const config of modelsData as ChatModelConfig[]) {
      const model = toCodebuddyModel(config);
      const discovered = live.find((entry) => entry.id === model.id)!;
      expect(discovered).toBeDefined();
      expect(model.thinkingLevelMap).toEqual(discovered.thinkingLevelMap);
      expect(getSupportedThinkingLevels(model)).toEqual(getSupportedThinkingLevels(discovered));
      expect(model.contextWindow).toBe(discovered.contextWindow);
      expect(model.maxTokens).toBe(discovered.maxTokens);
      expect(model.input).toEqual(discovered.input);
    }
  });

  it.each(modelsData as ChatModelConfig[])("clamps all levels for fallback $id", async (config) => {
    const model = toCodebuddyModel(config);
    for (const [index, level] of levels.entries()) {
      const payload = await capturePayload(model, level);
      expect(payload.thinking).toEqual({ type: "enabled" });
      expect(payload.reasoning_effort).toBe(expectedEfforts[model.id][index]);
    }
  });
});

describe("CodeBuddy live reasoning payloads", () => {
  it.each(catalog)("preserves Pi clamping and the allowlist for $id", async (source) => {
    const model = (await liveModels()).find((entry) => entry.id === source.id)!;
    const declared = source.reasoning.supportedEfforts;
    expect(getSupportedThinkingLevels(model)).toEqual(
      declared ?? ["minimal", "low", "medium", "high"],
    );
    for (const [index, level] of levels.entries()) {
      const payload = await capturePayload(model, level);
      expect(payload.model).toBe(source.id);
      expect(payload.thinking).toEqual({ type: "enabled" });
      expect(payload.reasoning_effort).toBe(expectedEfforts[source.id][index]);
      if (declared) expect(declared).toContain(payload.reasoning_effort);
    }
  });

  it.each(catalog)(
    "does not force default effort when reasoning is unset for $id",
    async (source) => {
      const model = (await liveModels()).find((entry) => entry.id === source.id)!;
      // Both stream entry points must leave effort selection to the gateway.
      for (const raw of [false, true]) {
        const payload = await capturePayload(model, undefined, raw);
        expect(payload).not.toHaveProperty("reasoning_effort");
        expect(payload).not.toHaveProperty("thinking");
      }
    },
  );

  it.each(modelsData as ChatModelConfig[])(
    "leaves reasoning unset for fallback $id",
    async (config) => {
      const payload = await capturePayload(toCodebuddyModel(config));
      expect(payload).not.toHaveProperty("reasoning_effort");
      expect(payload).not.toHaveProperty("thinking");
    },
  );

  it("still sends disabled thinking when a model actually supports off", async () => {
    const model = {
      ...toCodebuddyModel(modelsData[0] as ChatModelConfig),
      thinkingLevelMap: undefined,
    };
    const payload = await capturePayload(model, "off");
    expect(payload.thinking).toEqual({ type: "disabled" });
    expect(payload).not.toHaveProperty("reasoning_effort");
  });
});
