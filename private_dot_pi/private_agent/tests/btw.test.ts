import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { InMemoryCredentialStore, InMemoryModelsStore, type Model } from "@earendil-works/pi-ai";
import {
  createAgentSession,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  type ExtensionContext,
  type ResourceLoader,
} from "@earendil-works/pi-coding-agent";
import { beforeAll, describe, expect, it } from "vitest";
import { createBtwResourceLoader } from "../extensions/btw.ts";

const ctx = {
  cwd: tmpdir(),
  getSystemPrompt: () => "Main instructions\n<cwd>\n/old/workspace\n</cwd>",
} as unknown as ExtensionContext;

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
  it("loads only websearch and webfetch for side questions", async () => {
    const loader = await createBtwResourceLoader(ctx);
    const result = loader.getExtensions();
    expect(result.errors).toEqual([]);
    expect(result.extensions).toHaveLength(2);
    expect(result.extensions.flatMap((extension) => [...extension.tools.keys()]).sort()).toEqual([
      "webfetch",
      "websearch",
    ]);
    expect(result.extensions.flatMap((extension) => [...extension.commands.keys()])).toEqual([]);
    expect(loader.getSkills().skills).toEqual([]);
    expect(loader.getAgentsFiles().agentsFiles).toEqual([]);
    expect(loader.getSystemPrompt()).toBe("Main instructions");

    const tools = ["read", "bash", "edit", "write", "websearch", "webfetch"];
    const session = await createSession(loader, tools);
    try {
      expect(session.getActiveToolNames().sort()).toEqual([...tools].sort());
    } finally {
      session.dispose();
    }
  });

  it("treats prompts matching file paths as literal text", async () => {
    const cwd = await mkdtemp(join(tmpdir(), "btw-prompts-"));
    try {
      const path = join(cwd, "prompt.md");
      await writeFile(path, "File content must not replace the prompt.");
      const loader = await createBtwResourceLoader(
        { ...ctx, cwd, getSystemPrompt: () => path },
        [path],
        false,
      );
      expect(loader.getSystemPrompt()).toBe(path);
      expect(loader.getAppendSystemPrompt()).toEqual([path]);
      expect(loader.getSystemPromptSource()).toBeUndefined();
      expect(loader.getAppendSystemPromptSources()).toEqual([]);
    } finally {
      await rm(cwd, { recursive: true, force: true });
    }
  });

  it("keeps summary sessions tool-free", async () => {
    const loader = await createBtwResourceLoader(ctx, ["Summarize only."], false);
    expect(loader.getExtensions().extensions).toEqual([]);
    expect(loader.getAppendSystemPrompt()).toEqual(["Summarize only."]);

    const session = await createSession(loader, []);
    try {
      expect(session.getActiveToolNames()).toEqual([]);
      expect(session.systemPrompt).toContain("Summarize only.");
    } finally {
      session.dispose();
    }
  });
});
