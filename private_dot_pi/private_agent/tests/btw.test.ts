import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { InMemoryCredentialStore, InMemoryModelsStore, type Model } from "@earendil-works/pi-ai";
import {
  createAgentSession,
  createSyntheticSourceInfo,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  type BuildSystemPromptOptions,
  type ExtensionCommandContext,
  type ResourceLoader,
} from "@earendil-works/pi-coding-agent";
import { beforeAll, describe, expect, it, vi } from "vitest";
import { createBtwResourceLoader } from "../extensions/btw.ts";

const basePrompt: BuildSystemPromptOptions = {
  cwd: tmpdir(),
  appendSystemPrompt: "Keep user preferences.",
  contextFiles: [{ path: "/virtual/AGENTS.md", content: "Always respond in Chinese." }],
  skills: [{
    name: "research",
    description: "Research guidance",
    filePath: "/virtual/research/SKILL.md",
    baseDir: "/virtual/research",
    sourceInfo: createSyntheticSourceInfo("/virtual/research/SKILL.md", { source: "test" }),
    disableModelInvocation: false,
  }],
  selectedTools: ["codemode"],
  hiddenTools: ["read"],
  toolSnippets: { codemode: "Main-only tool description." },
  promptGuidelines: ["Main-only guideline."],
  sections: { workflow: "Main-only workflow." },
  forceSystemPrompt: "Main-only forced prompt.",
};
const ctx = {
  cwd: tmpdir(),
  getSystemPromptOptions: () => basePrompt,
  getSystemPrompt: vi.fn(() => { throw new Error("Do not inherit the rendered prompt."); }),
} as unknown as ExtensionCommandContext;

const model: Model<"openai-completions"> = {
  id: "btw-offline",
  name: "BTW offline test",
  provider: "btw-test",
  api: "openai-completions",
  baseUrl: "https://never-called.invalid",
  input: ["text"],
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  reasoning: false,
  contextWindow: 100_000,
  maxTokens: 100,
};
let modelRuntime: ModelRuntime;
beforeAll(async () => {
  modelRuntime = await ModelRuntime.create({
    credentials: new InMemoryCredentialStore(),
    modelsPath: null,
    modelsStore: new InMemoryModelsStore(),
    refreshOnCreate: false,
    allowModelNetwork: false,
  });
});

async function createSession(resourceLoader: ResourceLoader, tools: string[]) {
  const { session } = await createAgentSession({
    cwd: ctx.cwd,
    model,
    modelRuntime,
    resourceLoader,
    tools,
    sessionManager: SessionManager.inMemory(ctx.cwd),
    settingsManager: SettingsManager.inMemory({ cacheWarming: "off" }),
  });
  await session.bindExtensions({});
  return session;
}

describe("BTW resources", () => {
  it("inherits base resources but generates its own tool instructions", async () => {
    const loader = await createBtwResourceLoader(ctx);
    const result = loader.getExtensions();
    expect(result.errors).toEqual([]);
    expect(result.extensions).toHaveLength(2);
    expect(result.extensions.flatMap((extension) => [...extension.tools.keys()]).sort()).toEqual([
      "webfetch", "websearch",
    ]);
    expect(result.extensions.flatMap((extension) => [...extension.commands.keys()])).toEqual([]);
    expect(loader.getSkills().skills).toEqual([]);
    expect(loader.getAgentsFiles().agentsFiles).toEqual(basePrompt.contextFiles);
    expect(loader.getSystemPrompt()).toBeUndefined();

    const tools = ["read", "bash", "edit", "write", "websearch", "webfetch"];
    const session = await createSession(loader, tools);
    try {
      expect(session.getActiveToolNames().sort()).toEqual([...tools].sort());
      expect(session.systemPrompt).toContain("<tools>");
      expect(session.systemPrompt).toContain("- read:");
      expect(session.systemPrompt).toContain("Keep user preferences.");
      expect(session.systemPrompt).toContain("Always respond in Chinese.");
      expect(session.systemPrompt).not.toContain("<skills>");
      expect(session.systemPrompt).not.toContain("<name>research</name>");
      expect(session.systemPrompt).toContain("You are BTW, a side-channel assistant");
      expect(session.systemPrompt).toContain("You have access to the main conversation context");
      expect(session.systemPrompt).not.toContain("- codemode:");
      expect(session.systemPrompt).not.toContain("Main-only");
      expect(basePrompt.selectedTools).toEqual(["codemode"]);
      expect(basePrompt.skills![0].disableModelInvocation).toBe(false);
      expect(loader.getAgentsFiles().agentsFiles[0]).not.toBe(basePrompt.contextFiles![0]);
    } finally {
      session.dispose();
    }
  });

  it("does not read main-session skills", async () => {
    const getSkills = vi.fn(() => { throw new Error("BTW should not inherit skills."); });
    const loader = await createBtwResourceLoader({
      ...ctx,
      getSystemPromptOptions: () => ({ ...basePrompt, get skills() { return getSkills(); } }),
    });
    expect(getSkills).not.toHaveBeenCalled();
    expect(loader.getSkills().skills).toEqual([]);
  });

  it("preserves explicit custom user prompts as literal text", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "btw-prompts-"));
    try {
      const path = join(cwd, "prompt.md");
      await writeFile(path, "File content must not replace the prompt.");
      const loader = await createBtwResourceLoader({
        ...ctx,
        cwd,
        getSystemPromptOptions: () => ({ ...basePrompt, customPrompt: path, appendSystemPrompt: path }),
      });
      expect(loader.getSystemPrompt()).toBe(path);
      expect(loader.getAppendSystemPrompt()[0]).toBe(path);
      expect(loader.getSystemPromptSource()).toBeUndefined();
      expect(loader.getAppendSystemPromptSources()).toEqual([]);

      const session = await createSession(loader, []);
      try {
        expect(session.systemPrompt).toContain(path);
        expect(session.systemPrompt).not.toContain("File content must not replace the prompt.");
      } finally {
        session.dispose();
      }
    } finally {
      await rm(cwd, { recursive: true, force: true });
    }
  });

  it("keeps summary sessions independent of main instructions and tools", async () => {
    const getSystemPromptOptions = vi.fn(() => { throw new Error("Summary needs no main prompt."); });
    const loader = await createBtwResourceLoader(
      { ...ctx, getSystemPromptOptions }, ["Summarize only."], false,
    );
    expect(getSystemPromptOptions).not.toHaveBeenCalled();
    const { extensions, errors } = loader.getExtensions();
    expect(errors).toEqual([]);
    expect(extensions).toEqual([]);
    expect(loader.getSystemPrompt()).toBe("Summarize only.");
    expect(loader.getAppendSystemPrompt()).toEqual([]);
    expect(loader.getSkills().skills).toEqual([]);
    expect(loader.getAgentsFiles().agentsFiles).toEqual([]);

    const session = await createSession(loader, []);
    try {
      expect(session.getActiveToolNames()).toEqual([]);
      expect(session.systemPrompt).toContain("Summarize only.");
      expect(session.systemPrompt).not.toContain("<tools>");
      expect(session.systemPrompt).not.toContain("Keep user preferences.");
      expect(session.systemPrompt).not.toContain("Always respond in Chinese.");
      expect(session.systemPrompt).not.toContain("BTW");
    } finally {
      session.dispose();
    }
  });
});
