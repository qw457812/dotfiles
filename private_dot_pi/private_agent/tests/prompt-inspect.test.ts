import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { afterEach, expect, it, vi } from "vitest";
import promptInspect, {
  collectSystemPromptUpdates,
  extractSystemFromPayload,
} from "../extensions/prompt-inspect.js";

const { writeFileSync } = vi.hoisted(() => ({ writeFileSync: vi.fn() }));
vi.mock("node:fs", async (importOriginal) => ({
  ...(await importOriginal<typeof import("node:fs")>()),
  mkdtempSync: () => "/test/prompt-inspect",
  rmSync: vi.fn(),
  writeFileSync,
}));
vi.mock("node:child_process", () => ({
  spawn: () => ({
    on(event: string, callback: () => void) {
      if (event === "close") queueMicrotask(callback);
    },
  }),
}));

afterEach(() => {
  vi.unstubAllEnvs();
  writeFileSync.mockClear();
});

function registerPromptInspect() {
  const handlers = new Map<string, (event: unknown, ctx: ExtensionCommandContext) => unknown>();
  let command: Parameters<ExtensionAPI["registerCommand"]>[1] | undefined;
  promptInspect({
    on: (event: string, handler: (event: unknown, ctx: ExtensionCommandContext) => unknown) => {
      handlers.set(event, handler);
    },
    registerCommand: (_name: string, options: typeof command) => {
      command = options;
    },
  } as unknown as ExtensionAPI);
  return { handlers, command };
}

const prompt = "Base instructions\n<ponytail>\nPONYTAIL MODE ACTIVE\n</ponytail>";

it("extracts Command Code params.system without confusing config with system instructions", () => {
  const payload = {
    config: { workingDir: "/test", environment: "test" },
    memory: null,
    taste: null,
    skills: null,
    params: {
      model: "test-model",
      messages: [{ role: "user", content: [{ type: "text", text: "hello" }] }],
      system: prompt,
      stream: true,
    },
    threadId: "test-thread",
  };
  expect(extractSystemFromPayload(payload)).toBe(prompt);
});

it.each([
  { params: { system: [{ type: "text", text: prompt }] } },
  { instructions: prompt },
  { system: prompt },
  { system: [{ type: "text", text: prompt }] },
  { config: { systemInstruction: { parts: [{ text: prompt }] } } },
  { messages: [{ role: "system", content: prompt }] },
  { input: [{ role: "developer", content: [{ type: "input_text", text: prompt }] }] },
])("extracts supported system instructions from %j", (payload) => {
  expect(extractSystemFromPayload(payload)).toBe(prompt);
});

it.each([null, {}, { params: null }, { params: { system: 42 } }])(
  "does not invent instructions for unsupported payload %j",
  (payload) => {
    expect(extractSystemFromPayload(payload)).toBeUndefined();
  },
);

it("clears the previous response and assistant when a new request begins", async () => {
  vi.stubEnv("VISUAL", "test-editor");
  const { handlers, command } = registerPromptInspect();
  const ctx = {
    mode: "tui",
    getSystemPrompt: () => prompt,
    ui: {
      notify: vi.fn(),
      custom: (factory: (...args: unknown[]) => unknown) =>
        new Promise<void>((resolve) => {
          factory({ stop: vi.fn(), start: vi.fn(), requestRender: vi.fn() }, {}, {}, resolve);
        }),
    },
  } as unknown as ExtensionCommandContext;
  const emit = (event: string, data: unknown) => handlers.get(event)!(data, ctx);
  const dump = async () => {
    await command!.handler("payload", ctx);
    const text = writeFileSync.mock.lastCall![1] as string;
    return JSON.parse(text);
  };

  const response = { status: 200, headers: { "content-type": "application/json" } };
  const assistant = { role: "assistant", content: [{ type: "text", text: "Old answer" }] };
  emit("before_provider_request", { payload: { system: "First request" } });
  emit("after_provider_response", response);
  emit("message_end", { message: assistant });
  expect(await dump()).toMatchObject({
    provider: { request: { system: "First request" }, response },
    pi: { assistant },
  });

  // The next request fails before receiving a response or assistant message.
  emit("before_provider_request", { payload: { system: "Second request" } });
  expect(await dump()).toMatchObject({
    provider: { request: { system: "Second request" }, response: null },
    pi: { assistant: null },
  });
});

it("does not claim all stages match when payload extraction fails", async () => {
  const { handlers, command } = registerPromptInspect();
  const ctx = {
    getSystemPrompt: () => prompt,
    sessionManager: {
      buildSessionProjection: () => ({ messages: [{ role: "system", content: prompt }] }),
    },
    ui: { notify: vi.fn() },
  } as unknown as ExtensionCommandContext;
  handlers.get("session_start")!({}, ctx);
  handlers.get("before_provider_request")!({ payload: {} }, ctx);
  await command!.handler("diff", ctx);
  expect(ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
    expect.stringContaining("Could not extract system from payload"),
    "warning",
  );
});

it("preserves section updates and removals without retaining mutable transcript references", () => {
  const initial = { role: "system", content: "base", timestamp: 1 };
  const update = { role: "system", content: "", sections: { ponytail: prompt }, timestamp: 2 };
  const removal = { role: "system", content: "", sections: { ponytail: null }, timestamp: 3 };
  const addition = {
    role: "system",
    content: [{ type: "text", text: "extra rule" }],
    timestamp: 4,
  };
  const updates = collectSystemPromptUpdates([
    initial,
    { role: "user", content: 'Updated system prompt section "fake":' },
    update,
    removal,
    addition,
    { role: "system", content: "", toolsRemoved: [{ name: "read" }] },
  ]);
  expect(updates).toEqual([update, removal, addition]);
  update.sections.ponytail = "changed later";
  expect(updates![0].sections?.ponytail).toBe(prompt);
});

it("distinguishes a known initial prompt from unknown transcript history", () => {
  expect(collectSystemPromptUpdates([{ role: "system", content: "base" }])).toEqual([]);
  expect(collectSystemPromptUpdates([])).toBeUndefined();
  expect(collectSystemPromptUpdates([{ role: "user", content: "hello" }])).toBeUndefined();
});

function historyFixture(
  messages: { role: string; content: string; sections?: Record<string, string | null> }[],
) {
  vi.stubEnv("VISUAL", "test-editor");
  const { handlers, command } = registerPromptInspect();
  let effective = "base";
  const ctx = {
    mode: "tui",
    getSystemPrompt: () => effective,
    sessionManager: { buildSessionProjection: () => ({ messages }) },
    ui: {
      notify: vi.fn(),
      custom: (factory: (...args: unknown[]) => unknown) =>
        new Promise<void>((resolve) => {
          factory({ stop: vi.fn(), start: vi.fn(), requestRender: vi.fn() }, {}, {}, resolve);
        }),
    },
  } as unknown as ExtensionCommandContext;
  handlers.get("session_start")!({}, ctx);
  return {
    ctx,
    request(payload: unknown, currentPrompt: string) {
      effective = currentPrompt;
      handlers.get("before_provider_request")!({ payload }, ctx);
    },
    async inspect(arg: string) {
      await command!.handler(arg, ctx);
      return writeFileSync.mock.lastCall?.[1] as string | undefined;
    },
  };
}

it("shows the base diff and separates extracted payload instructions from transcript updates", async () => {
  const messages = [
    { role: "system", content: "base" },
    { role: "system", content: "", sections: { ponytail: prompt } },
  ];
  const f = historyFixture(messages);
  f.request({ messages: [{ role: "system", content: "base" }] }, prompt);
  // Navigating the branch after the request must not alter the request snapshot.
  messages.length = 0;
  const text = await f.inspect("diff");
  expect(text).toContain("--- system-prompt.base");
  expect(text).not.toContain("Payload prompt inspection");
  expect(text).not.toContain('"payloadSystemInstructions":');
  expect(text).not.toContain('"transcriptUpdates":');
  expect(text).not.toContain("--- system-prompt.effective");
  expect(f.ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
    expect.stringContaining("transcript contains system prompt updates"),
    "info",
  );
  const dump = JSON.parse((await f.inspect("payload"))!);
  expect(dump.pi.systemPrompt.transcriptUpdates).toHaveLength(1);
  expect(dump.pi.systemPrompt.effective).toBe(prompt);
  expect(dump.pi.systemPrompt.payloadSystemInstructions).toBe("base");
  expect(dump.pi.systemPrompt).not.toHaveProperty("payloadInitialInstructions");
  expect(dump.pi.systemPrompt).not.toHaveProperty("note");
});

it("labels merged provider instructions neutrally while preserving transcript evidence", async () => {
  const f = historyFixture([
    { role: "system", content: "base" },
    { role: "system", content: "", sections: { ponytail: prompt } },
  ]);
  const mergedPrompt = `base\n\n${prompt}`;
  // A flattened provider sends the complete prompt, not only the initial instructions.
  f.request({ config: { systemInstruction: mergedPrompt } }, mergedPrompt);
  const dump = JSON.parse((await f.inspect("payload"))!);
  expect(dump.pi.systemPrompt.payloadSystemInstructions).toBe(mergedPrompt);
  expect(dump.pi.systemPrompt.effective).toBe(mergedPrompt);
  expect(dump.pi.systemPrompt.transcriptUpdates[0].sections.ponytail).toBe(prompt);
  expect(dump.pi.systemPrompt).not.toHaveProperty("payloadInitialInstructions");
  writeFileSync.mockClear();
  const text = await f.inspect("diff");
  expect(text).toContain("--- system-prompt.base");
  expect(text).not.toContain("--- system-prompt.effective");
  expect(f.ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
    expect.stringContaining("inspect extracted system instructions"),
    "info",
  );
});

it("keeps the request-time effective prompt visible after Pi resets the run options", async () => {
  const f = historyFixture([{ role: "system", content: "base" }]);
  f.request({ system: prompt }, prompt);
  expect(await f.inspect("")).toBe(prompt);

  // Pi clears run-specific prompt options when generation settles.
  vi.spyOn(f.ctx, "getSystemPrompt").mockReturnValue("base");
  expect(await f.inspect("")).toBe(prompt);
  expect(f.ctx.ui.notify).not.toHaveBeenCalled();

  vi.mocked(f.ctx.getSystemPrompt).mockReturnValue("next request prompt");
  f.request({ system: "next request prompt" }, "next request prompt");
  vi.mocked(f.ctx.getSystemPrompt).mockReturnValue("base");
  expect(await f.inspect("")).toBe("next request prompt");
});

it("shows the current base prompt before any provider request", async () => {
  const f = historyFixture([{ role: "system", content: "base" }]);
  expect(await f.inspect("")).toBe("base");
  expect(f.ctx.ui.notify).not.toHaveBeenCalled();
});

it("labels unknown history rather than claiming the payload matches", async () => {
  const f = historyFixture([]);
  f.request({ system: "base" }, "base");
  expect(await f.inspect("diff")).toBeUndefined();
  expect(writeFileSync).not.toHaveBeenCalled();
  expect(f.ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
    expect.stringContaining("transcript history unknown"),
    "info",
  );
});

it("does not open a diff when updates exist but the base prompt has not changed", async () => {
  const f = historyFixture([
    { role: "system", content: "base" },
    { role: "system", content: "", sections: { ponytail: null } },
  ]);
  f.request({ system: "base" }, "base");
  expect(await f.inspect("diff")).toBeUndefined();
  expect(writeFileSync).not.toHaveBeenCalled();
  expect(f.ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
    expect.stringContaining("comparison skipped"),
    "info",
  );
});

it("still compares effective and payload prompts when no transcript updates exist", async () => {
  const f = historyFixture([{ role: "system", content: "base" }]);
  f.request({ system: "changed by provider" }, "base");
  const text = await f.inspect("diff");
  expect(text).toContain("--- system-prompt.effective");
  expect(text).toContain("+++ system-prompt.payload");
  expect(text).not.toContain("comparison skipped");
});

it("reports matching stages only for a known history with no updates", async () => {
  const f = historyFixture([{ role: "system", content: "base" }]);
  f.request({ system: "base" }, "base");
  await f.inspect("diff");
  expect(writeFileSync).not.toHaveBeenCalled();
  expect(f.ctx.ui.notify).toHaveBeenCalledExactlyOnceWith(
    "System prompt diff: (none; all stages match)",
    "info",
  );
});
