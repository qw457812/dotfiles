import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Context } from "@deepseek-ai/cordis";
import type { Agent } from "@deepseek-ai/dsh-agent";
import type { CommandDefinition } from "@deepseek-ai/dsh-commands";
import { afterEach, describe, expect, test, vi } from "vitest";
import { apply } from "../src/index.js";

const temporaryDirs: string[] = [];

afterEach(() => {
  vi.unstubAllEnvs();
  for (const dir of temporaryDirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

function temporaryDir(prefix: string): string {
  const dir = mkdtempSync(join(tmpdir(), prefix));
  temporaryDirs.push(dir);
  return dir;
}

function createAgentDir(): string {
  const dir = temporaryDir("dsh-pi-prompts-agent-");
  mkdirSync(join(dir, "prompts"));
  return dir;
}

function createWorkspace(): string {
  const dir = temporaryDir("dsh-pi-prompts-workspace-");
  mkdirSync(join(dir, ".pi", "prompts"), { recursive: true });
  return dir;
}

interface TestHarness {
  ctx: Context;
  agents: Agent[];
  definitions: Array<{ agent: Agent; definition: CommandDefinition }>;
  warnings: string[];
  existingCommands: Set<string>;
  disposeAgent(agent: Agent): Promise<void>;
  disposePlugin(): Promise<void>;
}

function once(cleanup: () => void | Promise<void>): () => Promise<void> {
  let active = true;
  return async () => {
    if (!active) return;
    active = false;
    await cleanup();
  };
}

function createContext(cwds: string[], rootCount = cwds.length): TestHarness {
  const definitions: Array<{ agent: Agent; definition: CommandDefinition }> = [];
  const warnings: string[] = [];
  const existingCommands = new Set<string>();
  const rootCleanups: Array<() => Promise<void>> = [];
  const agentCleanups = new Map<Agent, Array<() => Promise<void>>>();
  const listeners = {
    created: new Set<(payload: { agent: Agent }) => void>(),
    disposed: new Set<(payload: { agent: Agent }) => void>(),
  };

  const agents = cwds.map((cwd, index) => {
    const agent = {
      id: `agent-${index}`,
      session: { header: { cwd } },
      steer: vi.fn(),
    } as unknown as Agent;
    const cleanups: Array<() => Promise<void>> = [];
    agentCleanups.set(agent, cleanups);
    let registrationOwner: Array<() => Promise<void>> | undefined;
    const scopedCommands = {
      find: vi.fn((target: Agent, commandName: string) => {
        if (existingCommands.has(commandName)) return { name: commandName };
        return definitions.find(
          (entry) => entry.agent === target && entry.definition.name === commandName,
        )?.definition;
      }),
      register: vi.fn((definition: CommandDefinition) => {
        if (
          definitions.some(
            (entry) => entry.agent === agent && entry.definition.name === definition.name,
          )
        ) {
          throw new Error(`command "${definition.name}" is already registered in this scope`);
        }
        const entry = { agent, definition };
        definitions.push(entry);
        const dispose = once(() => {
          const position = definitions.indexOf(entry);
          if (position >= 0) definitions.splice(position, 1);
        });
        registrationOwner?.push(dispose);
        return dispose;
      }),
    };
    const agentCtx = {
      inject: vi.fn((deps: string[], callback: (ctx: Context) => void) => {
        expect(deps).toEqual(["commands"]);
        const ownedRegistrations: Array<() => Promise<void>> = [];
        registrationOwner = ownedRegistrations;
        try {
          callback({ ...agentCtx, commands: scopedCommands } as unknown as Context);
        } finally {
          registrationOwner = undefined;
        }
        const dispose = once(async () => {
          for (const unregister of ownedRegistrations.reverse()) await unregister();
        });
        cleanups.push(dispose);
        return { dispose };
      }),
    };
    Object.assign(agent, { ctx: agentCtx });
    return agent;
  });

  const ctx = {
    agents: {
      roots: vi.fn(() => agents.slice(0, rootCount)),
    },
    commands: {
      find: vi.fn((agent: Agent, commandName: string) => {
        if (existingCommands.has(commandName)) return { name: commandName };
        return definitions.find(
          (entry) => entry.agent === agent && entry.definition.name === commandName,
        )?.definition;
      }),
    },
    logger: {
      warn: vi.fn((message: string) => warnings.push(message)),
    },
    on: vi.fn((event: string, listener: (payload: { agent: Agent }) => void) => {
      const target = event === "agent/created" ? listeners.created : listeners.disposed;
      target.add(listener);
      return () => target.delete(listener);
    }),
    effect: vi.fn((factory: () => void | (() => void | Promise<void>)) => {
      const returned = factory();
      const cleanup = once(typeof returned === "function" ? returned : () => undefined);
      rootCleanups.push(cleanup);
      return cleanup;
    }),
  } as unknown as Context;

  return {
    ctx,
    agents,
    definitions,
    warnings,
    existingCommands,
    async disposeAgent(agent: Agent) {
      for (const cleanup of [...(agentCleanups.get(agent) ?? [])].reverse()) await cleanup();
      for (const listener of listeners.disposed) listener({ agent });
      await Promise.resolve();
    },
    async disposePlugin() {
      for (const cleanup of [...rootCleanups].reverse()) await cleanup();
    },
  };
}

function trustProject(agentDir: string, workspace: string, decision = true): void {
  writeFileSync(
    join(agentDir, "trust.json"),
    `${JSON.stringify({ [realpathSync(workspace)]: decision }, null, 2)}\n`,
  );
}

describe("apply", () => {
  test("registers valid global prompts and diagnoses bad files", () => {
    const agentDir = createAgentDir();
    const promptsDir = join(agentDir, "prompts");
    writeFileSync(
      join(promptsDir, "valid.md"),
      [
        "---",
        "description: |",
        "  First line",
        "  Second: line",
        'argument-hint: "topic: detail"',
        "---",
        "Hello ${1:-world}: ${@:2}",
      ].join("\n"),
    );
    writeFileSync(join(promptsDir, "fallback.md"), "First body line\nSecond line\n");
    writeFileSync(join(promptsDir, "bad.md"), "---\ndescription: [broken\n---\nBody\n");
    writeFileSync(join(promptsDir, "empty.md"), "---\ndescription: Empty\n---\n  \n");
    writeFileSync(join(promptsDir, "1invalid.md"), "Skipped\n");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([createWorkspace()]);

    apply(harness.ctx);

    expect(harness.definitions.map(({ definition }) => definition.name).sort()).toEqual([
      "fallback",
      "valid",
    ]);
    const valid = harness.definitions.find(
      ({ definition }) => definition.name === "valid",
    )?.definition;
    expect(valid).toMatchObject({
      description: "First line\nSecond: line\n",
      input: { hint: "topic: detail" },
    });
    expect(
      harness.definitions.find(({ definition }) => definition.name === "fallback")?.definition
        .description,
    ).toBe("First body line");
    expect(harness.warnings).toHaveLength(2);
    expect(harness.warnings.join("\n")).toMatch(/cannot parse .*bad\.md/u);
    expect(harness.warnings.join("\n")).toMatch(/empty prompt body in .*empty\.md/u);
  });

  test("steers an identified user message with rendered prompt text", () => {
    const agentDir = createAgentDir();
    writeFileSync(join(agentDir, "prompts", "valid.md"), "Hello ${1:-world}: ${@:2}\n");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([createWorkspace()]);
    apply(harness.ctx);
    const handler = harness.definitions[0]?.definition.handler;
    const steer = vi.fn();

    const result = handler?.({
      agent: { steer } as never,
      attachments: [],
      commandId: "command-id" as never,
      rawInput: "Alice one two",
      signal: AbortSignal.timeout(1_000),
    });

    expect(result).toEqual({ kind: "success", text: 'Sent the pi prompt "valid".' });
    expect(steer.mock.calls[0]?.[0]).toMatchObject({
      role: "user",
      source: { kind: "user" },
      content: [{ type: "text", text: "Hello Alice: one two\n" }],
    });
  });

  test("returns an error when substitution renders an empty prompt", () => {
    const agentDir = createAgentDir();
    writeFileSync(join(agentDir, "prompts", "empty-render.md"), "$1");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([createWorkspace()]);
    apply(harness.ctx);

    const result = harness.definitions[0]?.definition.handler({
      agent: { steer: vi.fn() } as never,
      attachments: [],
      commandId: "command-id" as never,
      rawInput: "",
      signal: AbortSignal.timeout(1_000),
    });

    expect(result).toEqual({ kind: "error", text: "The prompt renders empty." });
  });

  test("lets a trusted project prompt override the global prompt", () => {
    const agentDir = createAgentDir();
    const workspace = createWorkspace();
    writeFileSync(join(agentDir, "prompts", "shared.md"), "Global prompt\n");
    writeFileSync(join(workspace, ".pi", "prompts", "shared.md"), "Project prompt\n");
    trustProject(agentDir, workspace);
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([workspace]);

    apply(harness.ctx);

    expect(harness.definitions).toHaveLength(1);
    const steer = vi.fn();
    harness.definitions[0]?.definition.handler({
      agent: { steer } as never,
      attachments: [],
      commandId: "command-id" as never,
      rawInput: "",
      signal: AbortSignal.timeout(1_000),
    });
    expect(steer.mock.calls[0]?.[0]).toMatchObject({
      content: [{ type: "text", text: "Project prompt\n" }],
    });
    expect(harness.warnings.join("\n")).toMatch(/shared\.md skipped; .*shared\.md has precedence/u);
  });

  test("does not load project prompts without Pi trust", () => {
    const agentDir = createAgentDir();
    const workspace = createWorkspace();
    writeFileSync(join(agentDir, "prompts", "global.md"), "Global prompt\n");
    writeFileSync(join(workspace, ".pi", "prompts", "project.md"), "Project prompt\n");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([workspace]);

    apply(harness.ctx);

    expect(harness.definitions.map(({ definition }) => definition.name)).toEqual(["global"]);
  });

  test("fails project trust closed without losing global prompts", () => {
    const agentDir = createAgentDir();
    const workspace = createWorkspace();
    writeFileSync(join(agentDir, "prompts", "global.md"), "Global prompt\n");
    writeFileSync(join(workspace, ".pi", "prompts", "project.md"), "Project prompt\n");
    writeFileSync(join(agentDir, "trust.json"), '{"/tmp/project":"yes"}\n');
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([workspace]);

    apply(harness.ctx);

    expect(harness.definitions.map(({ definition }) => definition.name)).toEqual(["global"]);
    expect(harness.warnings.join("\n")).toMatch(/cannot resolve project trust/u);
  });

  test("preserves an existing DSH command instead of shadowing it", () => {
    const agentDir = createAgentDir();
    writeFileSync(join(agentDir, "prompts", "plan.md"), "Prompt plan\n");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([createWorkspace()]);
    harness.existingCommands.add("plan");

    apply(harness.ctx);

    expect(harness.definitions).toEqual([]);
    expect(harness.warnings.join("\n")).toMatch(/prompt "\/plan" .* a command already owns/u);
  });

  test("isolates project prompts by agent cwd", () => {
    const agentDir = createAgentDir();
    const first = createWorkspace();
    const second = createWorkspace();
    writeFileSync(join(first, ".pi", "prompts", "first.md"), "First\n");
    writeFileSync(join(second, ".pi", "prompts", "second.md"), "Second\n");
    writeFileSync(
      join(agentDir, "trust.json"),
      `${JSON.stringify({ [realpathSync(first)]: true, [realpathSync(second)]: true })}\n`,
    );
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([first, second]);

    apply(harness.ctx);

    expect(
      harness.definitions
        .filter(({ agent }) => agent === harness.agents[0])
        .map(({ definition }) => definition.name),
    ).toEqual(["first"]);
    expect(
      harness.definitions
        .filter(({ agent }) => agent === harness.agents[1])
        .map(({ definition }) => definition.name),
    ).toEqual(["second"]);
  });

  test("does not install commands for non-root agents", () => {
    const agentDir = createAgentDir();
    writeFileSync(join(agentDir, "prompts", "global.md"), "Global\n");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([createWorkspace(), createWorkspace()], 1);

    apply(harness.ctx);

    expect(harness.definitions).toHaveLength(1);
    expect(harness.definitions[0]?.agent).toBe(harness.agents[0]);
  });

  test("removes scoped registrations with either agent or plugin disposal", async () => {
    const agentDir = createAgentDir();
    writeFileSync(join(agentDir, "prompts", "global.md"), "Global\n");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([createWorkspace(), createWorkspace()]);
    apply(harness.ctx);
    expect(harness.definitions).toHaveLength(2);

    await harness.disposeAgent(harness.agents[0] as Agent);
    expect(harness.definitions).toHaveLength(1);

    await harness.disposePlugin();
    expect(harness.definitions).toEqual([]);
  });

  test("treats missing prompt directories as empty", () => {
    const agentDir = temporaryDir("dsh-pi-prompts-empty-agent-");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const harness = createContext([createWorkspace()]);

    apply(harness.ctx);

    expect(harness.definitions).toEqual([]);
    expect(harness.warnings).toEqual([]);
  });
});
