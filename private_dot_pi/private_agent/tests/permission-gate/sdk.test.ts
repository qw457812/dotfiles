import { copyFile, mkdir, mkdtemp, readFile, rm, symlink } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  createAssistantMessageEventStream,
  InMemoryModelsStore,
  type AssistantMessage,
  type ClassifierModel,
  type ClassifierResult,
  type Model,
} from "@earendil-works/pi-ai";
import {
  createAgentSession,
  DefaultResourceLoader,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  type AgentSession,
  type ExtensionContext,
  type InputEvent,
  type InputEventResult,
} from "@earendil-works/pi-coding-agent";
// AuthStorage is internal in this SDK version; use it only to isolate credentials.
import { AuthStorage } from "../../node_modules/@earendil-works/pi-coding-agent/dist/core/auth-storage.js";
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { GATE_ENTRY } from "../../extensions/permission-gate/index.ts";
import { latestUserIntent, userText } from "../../extensions/permission-gate/intent.ts";
import { GATE_QUESTIONS } from "../../extensions/permission-gate/jev.ts";
import type { GateRecord } from "../../extensions/permission-gate/log.ts";
import { initializeBashParser } from "../../lib/bash-parser.ts";

const templatePath = new URL("../../prompts/commit.md", import.meta.url);
const COMMAND = 'git commit -m "test: offline template regression"';
const COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
const CHAT: Model<"openai-completions"> = {
  id: "offline-chat",
  name: "Offline regression",
  provider: "permission-gate-offline",
  api: "openai-completions",
  baseUrl: "https://never-called.invalid",
  input: ["text"],
  cost: COST,
  reasoning: false,
  contextWindow: 100_000,
  maxTokens: 100,
};
const CLASSIFIER: ClassifierModel<"typesafe-classifier"> = {
  type: "classifier",
  id: "jev-latest",
  name: "Offline Jev",
  provider: "typesafe",
  api: "typesafe-classifier",
  baseUrl: "https://never-called.invalid",
  input: ["text"],
  cost: COST,
  contextWindow: 100_000,
};
const APPROVED: ClassifierResult = {
  api: CLASSIFIER.api,
  provider: CLASSIFIER.provider,
  model: CLASSIFIER.id,
  answers: {
    intent_covered: { type: "bool", probability: 0.99 },
    scope_covered: { type: "bool", probability: 0.99 },
    unexpected_harm: { type: "bool", probability: 0.01 },
  },
  stopReason: "stop",
  timestamp: 0,
};

// A real agent run still emits/persists user message_end, but cannot call tools or HTTP.
function offlineResponse() {
  const message: AssistantMessage = {
    role: "assistant",
    content: [{ type: "text", text: "Offline response; no commands executed." }],
    api: CHAT.api,
    provider: CHAT.provider,
    model: CHAT.id,
    usage: { ...COST, totalTokens: 0, cost: { ...COST, total: 0 } },
    stopReason: "stop",
    timestamp: Date.now(),
  };
  const stream = createAssistantMessageEventStream();
  stream.push({ type: "done", reason: "stop", message });
  return stream;
}

function classifierMocks() {
  return {
    classify: vi.fn<ExtensionContext["modelRegistry"]["classify"]>().mockResolvedValue(APPROVED),
    findOfType: vi
      .fn<ExtensionContext["modelRegistry"]["findOfType"]>()
      .mockReturnValue(CLASSIFIER),
  };
}

describe("Permission Gate slash templates (real Pi SDK)", () => {
  let root: string;
  let session: AgentSession;
  let templateBody: string;
  let inputs: InputEvent[];
  let prompts: string[];
  let lifecycle: string[];
  let errors: string[];
  let intercept: ((event: InputEvent) => InputEventResult | undefined) | undefined;
  let classifier: ReturnType<typeof classifierMocks>;
  let stream: ReturnType<typeof vi.fn<typeof offlineResponse>>;
  let forbiddenProvider: ReturnType<typeof vi.fn<() => never>>;
  let forbiddenFetch: ReturnType<typeof vi.fn<() => never>>;

  beforeAll(initializeBashParser);

  beforeEach(async () => {
    inputs = [];
    prompts = [];
    lifecycle = [];
    errors = [];
    intercept = undefined;
    classifier = classifierMocks();
    stream = vi.fn(offlineResponse);
    forbiddenProvider = vi.fn(() => {
      throw new Error("Provider calls forbidden in template regression");
    });
    forbiddenFetch = vi.fn(() => {
      throw new Error("Network forbidden in template regression");
    });
    // Install before resource loading/runtime creation, not just before prompting.
    vi.stubGlobal("fetch", forbiddenFetch);
    root = await mkdtemp(join(tmpdir(), "pi-gate-template-"));
    const cwd = join(root, "workspace");
    const agentDir = join(root, "agent");
    await Promise.all([mkdir(cwd), mkdir(join(agentDir, "prompts"), { recursive: true })]);
    await copyFile(templatePath, join(agentDir, "prompts", "commit.md"));
    await mkdir(join(agentDir, "extensions"));
    // Directory-loaded code resolves shared dependencies relative to this isolated agent root.
    for (const name of ["lib", "node_modules"])
      await symlink(
        fileURLToPath(new URL(`../../${name}`, import.meta.url)),
        join(agentDir, name),
        "dir",
      );
    await symlink(
      fileURLToPath(new URL("../../extensions/permission-gate", import.meta.url)),
      join(agentDir, "extensions", "permission-gate"),
      "dir",
    );
    const rawTemplate = await readFile(templatePath, "utf8");
    // Independent expectation: do not use Pi's expansion helper to construct expected text.
    templateBody = rawTemplate.replace(/^---\n[\s\S]*?\n---\n/, "").trim();
    expect(templateBody).toContain("$@");

    const settingsManager = SettingsManager.inMemory({
      compaction: { enabled: false },
      retry: { enabled: false },
      cacheWarming: "off",
    });
    const modelRuntime = await ModelRuntime.create({
      credentials: AuthStorage.inMemory(),
      modelsPath: null,
      modelsStore: new InMemoryModelsStore(),
      refreshOnCreate: false,
      allowModelNetwork: false,
    });
    modelRuntime.registerProvider(CHAT.provider, {
      api: CHAT.api,
      baseUrl: CHAT.baseUrl,
      apiKey: "offline-fake-key",
      models: [CHAT],
      streamSimple: forbiddenProvider,
    });
    const resourceLoader = new DefaultResourceLoader({
      cwd,
      agentDir,
      settingsManager,
      noExtensions: false,
      noSkills: true,
      noThemes: true,
      noContextFiles: true,
      extensionFactories: [
        // Only the classifier facade is stubbed. Gate and SDK lifecycle remain real.
        (pi) => {
          pi.on("session_start", (_event, ctx) => {
            vi.spyOn(ctx.modelRegistry, "classify").mockImplementation(classifier.classify);
            vi.spyOn(ctx.modelRegistry, "findOfType").mockImplementation(classifier.findOfType);
          });
          pi.on("input", (event) => {
            inputs.push({ ...event });
            lifecycle.push("input");
          });
          pi.on("before_agent_start", (event) => {
            prompts.push(event.prompt);
            lifecycle.push("before_agent_start");
          });
        },
        (pi) => {
          // Handled/transformed input still exercises real SDK persistence.
          pi.on("input", (event) => intercept?.(event));
          pi.on("message_end", (event) => {
            if (event.message.role === "user") lifecycle.push("user:message_end");
          });
        },
      ],
    });
    await resourceLoader.reload();
    const loaded = resourceLoader.getExtensions();
    expect(loaded.errors).toEqual([]);
    // Directory discovery must load only index, not the two guards or queue again.
    expect(
      loaded.extensions.filter((extension) => !extension.path.startsWith("<inline")),
    ).toHaveLength(1);
    const gate = loaded.extensions.find((extension) =>
      extension.path.endsWith("/permission-gate/index.ts"),
    );
    expect(gate).toBeDefined();
    expect(gate!.handlers.get("tool_call")).toHaveLength(3);
    expect(resourceLoader.getPrompts().diagnostics).toEqual([]);
    expect(resourceLoader.getPrompts().prompts).toMatchObject([
      { name: "commit", filePath: join(agentDir, "prompts", "commit.md"), content: templateBody },
    ]);
    const created = await createAgentSession({
      cwd,
      agentDir,
      model: CHAT,
      modelRuntime,
      settingsManager,
      resourceLoader,
      sessionManager: SessionManager.inMemory(cwd),
      noTools: "all",
    });
    session = created.session;
    expect(created.extensionsResult.errors).toEqual([]);
    session.agent.streamFunction = stream;
    await session.bindExtensions({ onError: (error) => errors.push(error.error) });
    expect(session.getAllTools()).toEqual([]);
    expect(session.agent.state.tools).toEqual([]);
  });

  afterEach(async () => {
    try {
      if (session) await session.extensionRunner.emit({ type: "session_shutdown", reason: "quit" });
    } finally {
      session?.dispose();
      vi.restoreAllMocks();
      vi.unstubAllGlobals();
      if (root) await rm(root, { recursive: true, force: true });
    }
    expect(errors).toEqual([]);
    expect(forbiddenProvider).not.toHaveBeenCalled();
    expect(forbiddenFetch).not.toHaveBeenCalled();
  });

  function persistedUsers() {
    return session.sessionManager
      .getBranch()
      .flatMap((entry) =>
        entry.type === "message" && entry.message.role === "user"
          ? [{ id: entry.id, message: entry.message }]
          : [],
      );
  }

  function expectUser(text: string) {
    const user = persistedUsers().at(-1);
    expect(user).toBeDefined();
    expect(userText(user!.message.content)).toBe(text);
    expect(Object.keys(user!.message).sort()).toEqual(["content", "role", "timestamp"]);
    // The SDK persists the expanded text; Gate does not add message metadata.
    expect(session.sessionManager.buildSessionContext().messages).toContainEqual(user!.message);
    expect(session.messages).toContainEqual(user!.message);
    return user!;
  }

  async function checkGate(authorized: boolean, text?: string) {
    classifier.classify.mockClear();
    classifier.findOfType.mockClear();
    // Dispatch only the permission hook: no Bash tool is registered or executed.
    const result = await session.extensionRunner.emitToolCall({
      type: "tool_call",
      toolCallId: "offline-commit",
      toolName: "bash",
      input: { command: COMMAND },
    });
    if (authorized) {
      expect(result).toBeUndefined();
      expect(classifier.findOfType).toHaveBeenCalledExactlyOnceWith(
        "classifier",
        "typesafe",
        "jev-latest",
      );
      expect(classifier.classify).toHaveBeenCalledOnce();
      expect(classifier.classify.mock.calls[0][1]).toEqual({
        state: {
          command: COMMAND,
          user_intent: text,
          cwd: join(root, "workspace"),
          matched_rules: ["git"],
        },
        questions: GATE_QUESTIONS,
      });
    } else {
      expect(result).toEqual({ block: true, reason: "Command requires user confirmation" });
      expect(classifier.classify).not.toHaveBeenCalled();
      expect(classifier.findOfType).not.toHaveBeenCalled();
    }
    const record = session.sessionManager
      .getBranch()
      .findLast((entry) => entry.type === "custom" && entry.customType === GATE_ENTRY);
    expect(record?.type).toBe("custom");
    const data = record?.type === "custom" ? (record.data as GateRecord) : undefined;
    expect(data?.judgment.reason).toBe(authorized ? "approved" : "missing-intent");
    expect(data?.outcome).toBe(authorized ? "auto-approved" : "no-ui");
  }

  it.each(["interactive", "rpc"] as const)(
    "persists the expanded %s /commit text and classifies the entire template",
    async (source) => {
      await session.prompt("/commit", source === "rpc" ? { source } : undefined);
      const expanded = templateBody.replace("$@", "");
      const user = expectUser(expanded);
      expect(inputs).toMatchObject([{ text: "/commit", source, streamingBehavior: undefined }]);
      expect(prompts).toEqual([expanded]);
      expect(lifecycle).toEqual(["input", "before_agent_start", "user:message_end"]);
      expect(latestUserIntent(session.sessionManager.getBranch())).toEqual({
        id: user.id,
        text: expanded,
      });
      expect(stream).toHaveBeenCalledOnce();
      await checkGate(true, expanded);
    },
  );

  it.each(["interactive", "rpc"] as const)("expands quoted $@ arguments for %s", async (source) => {
    await session.prompt('/commit "Use scope template-tests" explain intent', { source });
    const expanded = templateBody.replace("$@", "Use scope template-tests explain intent");
    expectUser(expanded);
    expect(prompts).toEqual([expanded]);
    expect(expanded).not.toContain("$@");
    await checkGate(true, expanded);
  });

  it.each(["prompt", "sendUserMessage"] as const)(
    "%s extension injection expands /commit and can authorize as an ordinary user",
    async (method) => {
      if (method === "prompt") await session.prompt("/commit", { source: "extension" });
      else await session.sendUserMessage("/commit", { expandPromptTemplates: true });
      const expanded = templateBody.replace("$@", "");
      const latest = expectUser(expanded);
      expect(inputs).toMatchObject([{ text: "/commit", source: "extension" }]);
      expect(prompts).toEqual([expanded]);
      expect(latestUserIntent(session.sessionManager.getBranch())).toEqual({
        id: latest.id,
        text: expanded,
      });
      await checkGate(true, expanded);
    },
  );

  it("always uses the latest entry across identical expanded text and subsequent plain input", async () => {
    const expanded = templateBody.replace("$@", "");
    await session.prompt("/commit", { source: "extension" });
    expectUser(expanded);
    await session.prompt(expanded, { source: "rpc" });
    const human = expectUser(expanded);
    await checkGate(true, expanded);
    await session.sendUserMessage("/commit", { expandPromptTemplates: true });
    const injected = expectUser(expanded);
    expect(injected.id).not.toBe(human.id);
    expect(latestUserIntent(session.sessionManager.getBranch())).toEqual({
      id: injected.id,
      text: expanded,
    });
    await checkGate(true, expanded);
    const plain = "Commit only the currently staged changes with a test commit message.";
    await session.prompt(plain);
    const latest = expectUser(plain);
    expect(latestUserIntent(session.sessionManager.getBranch())).toEqual({
      id: latest.id,
      text: plain,
    });
    await checkGate(true, plain);
    expect(persistedUsers()).toHaveLength(4);
    expect(stream).toHaveBeenCalledTimes(4);
  });

  it("uses transformed persisted text rather than correlating it to raw input", async () => {
    const transformed = "Commit changes inserted by a transforming extension.";
    intercept = () => ({ action: "transform", text: transformed });
    await session.prompt("Explain the staged changes.");
    expectUser(transformed);
    await checkGate(true, transformed);
    intercept = undefined;
    await session.prompt("/commit", { source: "rpc" });
    const expanded = templateBody.replace("$@", "");
    expectUser(expanded);
    await checkGate(true, expanded);
  });

  it("handled input creates no authorization and does not affect subsequent expanded user text", async () => {
    intercept = () => ({ action: "handled" });
    await session.prompt("/commit", { source: "extension" });
    expect(persistedUsers()).toEqual([]);
    expect(stream).not.toHaveBeenCalled();
    await checkGate(false);
    intercept = undefined;
    await session.prompt("/commit", { source: "rpc" });
    const expanded = templateBody.replace("$@", "");
    expectUser(expanded);
    await checkGate(true, expanded);
  });

  it("the discovered index applies path and SQL guards exactly once without Jev", async () => {
    const confirm = vi.fn<ExtensionContext["ui"]["confirm"]>().mockResolvedValue(false);
    const abort = vi.fn();
    await session.bindExtensions({
      uiContext: { ...session.extensionRunner.createContext().ui, confirm },
      abortHandler: abort,
      onError: (error) => errors.push(error.error),
    });
    const call = (toolName: string, input: Record<string, unknown>) =>
      session.extensionRunner.emitToolCall({
        type: "tool_call",
        toolCallId: "offline-guard",
        toolName,
        input,
      });
    expect(await call("mcp__db__execute_sql", { sql: "SELECT 1" })).toBeUndefined();
    expect(confirm).not.toHaveBeenCalled();
    expect(await call("mcp__db__execute_sql", { sql: "UPDATE data SET value = 1" })).toMatchObject({
      block: true,
    });
    expect(confirm).toHaveBeenCalledOnce();
    for (const tool of ["write", "edit"])
      expect(await call(tool, { path: "/repo/.env" })).toEqual({
        block: true,
        reason: "Protected path: .env",
      });
    expect(confirm.mock.calls.map(([title]) => title)).toEqual([
      "⚠️ SQL Guard",
      "🛡️ Protected Path",
      "🛡️ Protected Path",
    ]);
    expect(abort).toHaveBeenCalledTimes(3);
    expect(classifier.classify).not.toHaveBeenCalled();
    expect(session.getAllTools()).toEqual([]);
  });
});
