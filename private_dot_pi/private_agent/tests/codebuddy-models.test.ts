import type { AnyModel, Provider } from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
  ModelSelectEvent,
  SessionStartEvent,
} from "@earendil-works/pi-coding-agent";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CHAT_BASE_URL, PROVIDER } from "../extensions/codebuddy-provider/constants.js";
import register from "../extensions/codebuddy-provider/index.js";
import { fetchLiveModels } from "../extensions/codebuddy-provider/live-models.js";
import {
  type ChatModelConfig,
  getCodebuddyModelOptions,
  isCodebuddyModel,
  parseCodebuddyCredits,
  toCodebuddyModel,
} from "../extensions/codebuddy-provider/models.js";
import modelsData from "../extensions/codebuddy-provider/models.json" with { type: "json" };

const configs = modelsData as ChatModelConfig[];
const chat = toCodebuddyModel(configs[0]);

afterEach(() => vi.unstubAllGlobals());

describe("CodeBuddy credits parsing", () => {
  it.each([
    ["Model (x0.11 credits)", { label: "x0.11 credits", multiplier: "x0.11", rate: 0.11 }],
    ["Model (x0.00 credits)", { label: "x0.00 credits", multiplier: "x0.00", rate: 0 }],
    ["Model (preview) (x1.62)", { label: "x1.62", multiplier: "x1.62", rate: 1.62 }],
    ["Model", undefined],
    ["Model (xunknown credits)", undefined],
    ["Model (x0.11 credits) preview", undefined],
  ])("parses %s", (name, expected) => {
    expect(parseCodebuddyCredits(name)).toEqual(expected);
  });
});

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

  it.each([
    ["x0.79 credits", "GLM (x0.79 credits)"],
    ["x0.00 credits", "GLM (x0.00 credits)"],
    ["x1.62", "GLM (x1.62)"],
    ["  x0.06 credits  ", "GLM (x0.06 credits)"],
    [undefined, "GLM"],
    ["", "GLM"],
    ["   ", "GLM"],
  ])("displays credits %j without changing token costs", async (credits, name) => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response(
            JSON.stringify({
              code: 0,
              data: { models: [{ id: "glm", name: "GLM", credits }] },
            }),
          ),
      ),
    );

    const models = await fetchLiveModels({ accessToken: "test-token" });
    expect(models[0]).toMatchObject({
      id: "glm",
      name,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    });
  });

  it("lists only CodeBuddy models by numeric credits, with unknown rates last", () => {
    const models: AnyModel[] = [
      { ...chat, id: "expensive", name: "Expensive (x10.00 credits)" },
      { ...chat, id: "unknown", name: "Unknown" },
      { ...chat, id: "cheap", name: "Cheap (x0.05 credits)" },
      { ...chat, id: "free", name: "Free (x0.00 credits)" },
      { ...chat, id: "paid", name: "Paid (x1.62)" },
      { ...chat, id: "other", provider: "other" },
      { ...chat, id: "image", type: "image", output: ["image"] },
    ];
    const options = getCodebuddyModelOptions(models);
    expect(options.map((option) => option.label)).toEqual([
      "free       x0.00 credits",
      "cheap      x0.05 credits",
      "paid       x1.62",
      "expensive  x10.00 credits",
      "unknown    credits unknown",
    ]);
    expect(options.map((option) => option.model)).toEqual([
      models[3],
      models[2],
      models[4],
      models[0],
      models[1],
    ]);
    expect(getCodebuddyModelOptions([])).toEqual([]);
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

const cheap = { ...chat, id: "cheap", name: "Cheap (x0.05 credits)" };
const expensive = { ...chat, id: "expensive", name: "Expensive (x10 credits)" };

function setupPicker({
  selection,
  hasUI = true,
  models = [expensive, cheap],
  authenticated = true,
}: {
  selection?: string;
  hasUI?: boolean;
  models?: (typeof cheap)[];
  authenticated?: boolean;
} = {}) {
  const pi = {
    registerProvider: vi.fn(),
    registerCommand: vi.fn(),
    on: vi.fn(),
    setModel: vi.fn().mockResolvedValue(authenticated),
  };
  register(pi as unknown as ExtensionAPI);
  const handler = pi.registerCommand.mock.calls[0][1].handler;
  const ctx = {
    hasUI,
    modelRegistry: { getAll: () => models },
    ui: { select: vi.fn().mockResolvedValue(selection), notify: vi.fn() },
  };
  return { pi, ctx, run: () => handler("", ctx as unknown as ExtensionCommandContext) };
}

describe("CodeBuddy credits status", () => {
  function setupStatus(model: AnyModel | undefined, hasUI = true) {
    const { pi } = setupPicker();
    let activeModel = model;
    const ctx = {
      get model() {
        return activeModel;
      },
      hasUI,
      ui: { setStatus: vi.fn(), theme: { fg: vi.fn((_color, text) => `dim:${text}`) } },
    };
    const emit = (event: "session_start" | "model_select", selected = model) => {
      const handler = pi.on.mock.calls.find(([name]) => name === event)![1];
      let payload: SessionStartEvent | ModelSelectEvent;
      if (event === "session_start") {
        payload = { type: event, reason: "startup" };
      } else {
        if (!selected || selected.type === "image" || selected.type === "classifier") {
          throw new Error("model_select requires a chat model");
        }
        // Pi updates the active model before emitting model_select; ctx.model is a getter.
        activeModel = selected;
        payload = { type: event, model: selected, previousModel: undefined, source: "set" };
      }
      return handler(payload, ctx as unknown as ExtensionContext);
    };
    const provider = pi.registerProvider.mock.calls[0][0] as Provider<"openai-completions">;
    const shutdown = () => {
      const handler = pi.on.mock.calls.find(([name]) => name === "session_shutdown")![1];
      handler({ type: "session_shutdown" }, ctx as unknown as ExtensionContext);
    };
    return { ctx, emit, provider, shutdown };
  }

  async function refreshCatalog(
    provider: Provider<"openai-completions">,
    models: (typeof cheap)[],
    { allowNetwork = false, accepted = true } = {},
  ) {
    await provider.refreshModels!({
      stored: { models, checkedAt: Date.now() },
      credential: { type: "api_key", key: "test-token" },
      allowNetwork,
      signal: new AbortController().signal,
      publish: async (publication) => {
        if (accepted) publication.update?.();
        return accepted;
      },
    });
  }

  it("shows cached credits even when publication precedes session start", async () => {
    const { ctx, emit, provider } = setupStatus({ ...cheap, name: "Cheap" });
    await refreshCatalog(provider, [cheap]);
    emit("session_start");
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", "dim:x0.05");
  });

  it("updates credits after live publication without a model selection event", async () => {
    const { ctx, emit, provider } = setupStatus(cheap);
    emit("session_start");
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response(
            JSON.stringify({
              code: 0,
              data: { models: [{ id: cheap.id, name: "Cheap", credits: "x0.15 credits" }] },
            }),
          ),
      ),
    );
    await refreshCatalog(provider, [cheap], { allowNetwork: true });
    expect(ctx.model).toBe(cheap);
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", "dim:x0.15");
  });

  it("uses the published catalog on later model selection", async () => {
    const { ctx, emit, provider } = setupStatus(cheap);
    emit("session_start");
    await refreshCatalog(provider, [{ ...cheap, name: "Cheap (x0.15 credits)" }]);
    emit("model_select", cheap);
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", "dim:x0.15");
  });

  it("clears credits when the published model loses its rate or disappears", async () => {
    const { ctx, emit, provider } = setupStatus(cheap);
    emit("session_start");
    await refreshCatalog(provider, [{ ...cheap, name: "Cheap" }]);
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", undefined);
    await refreshCatalog(provider, [expensive]);
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", undefined);
  });

  it("does not apply a rejected publication", async () => {
    const { ctx, emit, provider } = setupStatus(cheap);
    emit("session_start");
    await refreshCatalog(provider, [{ ...cheap, name: "Cheap (x0.15 credits)" }], {
      accepted: false,
    });
    expect(ctx.ui.setStatus).toHaveBeenCalledExactlyOnceWith(
      "codebuddy-model-credits",
      "dim:x0.05",
    );
  });

  it("does not restore credits for another provider or update a shut down UI", async () => {
    const { ctx, emit, provider, shutdown } = setupStatus(cheap);
    emit("session_start");
    emit("model_select", { ...cheap, provider: "other" });
    await refreshCatalog(provider, [cheap]);
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", undefined);
    shutdown();
    ctx.ui.setStatus.mockClear();
    await refreshCatalog(provider, [cheap]);
    expect(ctx.ui.setStatus).not.toHaveBeenCalled();
  });

  it.each(["x0.11 credits", "x0.00 credits", "x1.62"])(
    "shows only the multiplier on session start: %s",
    (credits) => {
      const { ctx, emit } = setupStatus({ ...chat, name: `Model (${credits})` });
      emit("session_start");
      expect(ctx.ui.setStatus).toHaveBeenCalledExactlyOnceWith(
        "codebuddy-model-credits",
        `dim:${credits.split(" ")[0]}`,
      );
    },
  );

  it("updates from the selected model and clears stale credits", () => {
    const { ctx, emit } = setupStatus(cheap);
    emit("session_start");
    emit("model_select", expensive);
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", "dim:x10");
    emit("model_select", { ...cheap, provider: "other" });
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", undefined);
    emit("model_select", { ...cheap, name: "Unknown" });
    expect(ctx.ui.setStatus).toHaveBeenLastCalledWith("codebuddy-model-credits", undefined);
  });

  it("clears the status when no model is selected", () => {
    const { ctx, emit } = setupStatus(undefined);
    emit("session_start");
    expect(ctx.ui.setStatus).toHaveBeenCalledExactlyOnceWith("codebuddy-model-credits", undefined);
  });

  it("does not access status UI in non-interactive mode", () => {
    const { ctx, emit } = setupStatus(cheap, false);
    emit("session_start");
    emit("model_select", expensive);
    expect(ctx.ui.setStatus).not.toHaveBeenCalled();
  });
});

describe("/codebuddy-models picker", () => {
  it("shows models by credits and switches to the selected model", async () => {
    const { pi, ctx, run } = setupPicker({ selection: "cheap      x0.05 credits" });
    await run();
    expect(ctx.ui.select).toHaveBeenCalledWith("Select CodeBuddy model (lowest credits first)", [
      "cheap      x0.05 credits",
      "expensive  x10 credits",
    ]);
    expect(pi.setModel).toHaveBeenCalledWith(cheap);
    expect(ctx.ui.notify).toHaveBeenCalledWith("Switched to codebuddy/cheap", "info");
  });

  it("leaves the active model unchanged on cancellation", async () => {
    const { pi, ctx, run } = setupPicker();
    await run();
    expect(pi.setModel).not.toHaveBeenCalled();
    expect(ctx.ui.notify).not.toHaveBeenCalled();
  });

  it.each([{ hasUI: false }, { models: [] }])(
    "does not open a picker when unavailable: %j",
    async (options) => {
      const { pi, ctx, run } = setupPicker(options);
      await run();
      expect(ctx.ui.select).not.toHaveBeenCalled();
      expect(pi.setModel).not.toHaveBeenCalled();
      if (options.hasUI === false) {
        expect(ctx.ui.notify).not.toHaveBeenCalled();
      } else {
        expect(ctx.ui.notify).toHaveBeenCalledWith("No CodeBuddy models available.", "warning");
      }
    },
  );

  it("reports missing credentials without announcing a successful switch", async () => {
    const { ctx, run } = setupPicker({
      selection: "cheap      x0.05 credits",
      authenticated: false,
    });
    await run();
    expect(ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
      "CodeBuddy credentials unavailable. Please run /login codebuddy first.",
      "error",
    );
  });
});
