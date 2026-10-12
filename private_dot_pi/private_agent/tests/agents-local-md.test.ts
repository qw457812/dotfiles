import {
  type BeforeAgentStartEvent,
  type ExtensionAPI,
  type ExtensionContext,
  type Skill,
} from "@earendil-works/pi-coding-agent";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, expect, it, vi } from "vitest";
import {
  buildSystemPrompt,
  normalizeBuildSystemPromptOptions,
} from "../node_modules/@earendil-works/pi-coding-agent/dist/core/system-prompt.js";
import agentsLocalMd from "../extensions/agents-local-md.js";
import skillVisibility from "../extensions/skill-visibility.js";

const { agentDir } = vi.hoisted(() => ({ agentDir: { path: "" } }));
vi.mock("@earendil-works/pi-coding-agent", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@earendil-works/pi-coding-agent")>()),
  getAgentDir: () => agentDir.path,
}));

const directories: string[] = [];
afterEach(() => {
  for (const directory of directories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

function fixture(localFiles = true) {
  const directory = mkdtempSync(join(tmpdir(), "pi-agents-local-test-"));
  directories.push(directory);
  agentDir.path = join(directory, "agent");
  const cwd = join(directory, "project");
  mkdirSync(agentDir.path);
  mkdirSync(cwd);
  const localPath = join(cwd, "AGENTS.local.md");
  if (localFiles) {
    writeFileSync(join(agentDir.path, "AGENTS.local.md"), "Global local instructions");
    writeFileSync(localPath, "Project local instructions");
  }
  const options = normalizeBuildSystemPromptOptions({
    cwd,
    selectedTools: ["read"],
    contextFiles: [{ path: join(cwd, "AGENTS.md"), content: "Native instructions" }],
    skills: [
      {
        name: "ponytail-review",
        description: "test",
        filePath: "/test/ponytail-review/SKILL.md",
        baseDir: "/test/ponytail-review",
        disableModelInvocation: false,
        sourceInfo: { path: "/test", source: "test", scope: "user", origin: "top-level" },
      } satisfies Skill,
    ],
  });
  const handlers = new Map<string, Array<(event: unknown, ctx: ExtensionContext) => unknown>>();
  const api = {
    on: (name: string, handler: (event: unknown, ctx: ExtensionContext) => unknown) => {
      handlers.set(name, [...(handlers.get(name) ?? []), handler]);
    },
    registerCommand: vi.fn(),
  } as unknown as ExtensionAPI;
  const ctx = {
    cwd,
    mode: "print",
    getSystemPrompt: () => buildSystemPrompt(options),
    ui: { notify: vi.fn() },
  } as unknown as ExtensionContext;
  const event = {
    type: "before_agent_start",
    prompt: "test",
    get systemPrompt() {
      return buildSystemPrompt(options);
    },
    systemPromptOptions: options,
  } satisfies BeforeAgentStartEvent;
  const emit = async (name: string) => {
    for (const handler of handlers.get(name) ?? []) {
      const result = (await handler(event, ctx)) as { systemPrompt?: string } | undefined;
      if (result?.systemPrompt !== undefined) options.forceSystemPrompt = result.systemPrompt;
    }
  };
  return { api, ctx, options, emit, localPath };
}

it.each([true, false])("composes local context with skill visibility (local first: %s)", async (localFirst) => {
  const f = fixture();
  for (const extension of localFirst ? [agentsLocalMd, skillVisibility] : [skillVisibility, agentsLocalMd]) {
    extension(f.api);
  }
  await f.emit("session_start");
  f.ctx.ui.notify = vi.fn();
  await f.emit("before_agent_start");
  // Repeated dispatch must not duplicate context files.
  await f.emit("before_agent_start");
  f.options.sections.ponytail = "PONYTAIL MODE ACTIVE";
  const prompt = buildSystemPrompt(f.options);
  expect(f.options.forceSystemPrompt).toBeUndefined();
  expect(f.options.contextFiles).toHaveLength(3);
  expect(prompt).toContain("Native instructions");
  expect(prompt).toContain("Global local instructions");
  expect(prompt).toContain("Project local instructions");
  expect(prompt).toContain(f.localPath);
  expect(prompt.match(/<project_context>/g)).toHaveLength(1);
  expect(prompt).toContain("PONYTAIL MODE ACTIVE");
  expect(prompt).not.toContain("<name>ponytail-review</name>");
  expect(f.ctx.ui.notify).not.toHaveBeenCalled();
});

it("leaves the prompt unchanged when there are no local context files", async () => {
  const f = fixture(false);
  agentsLocalMd(f.api);
  await f.emit("session_start");
  const before = buildSystemPrompt(f.options);
  await f.emit("before_agent_start");
  expect(buildSystemPrompt(f.options)).toBe(before);
  expect(f.options.forceSystemPrompt).toBeUndefined();
});
