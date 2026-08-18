import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Context } from "@deepseek-ai/cordis";
import type { CommandDefinition } from "@deepseek-ai/dsh-commands";
import { afterEach, describe, expect, test, vi } from "vitest";
import { apply } from "../src/index.js";

const temporaryDirs: string[] = [];

afterEach(() => {
  vi.unstubAllEnvs();
  for (const dir of temporaryDirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

function createAgentDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "dsh-pi-prompts-"));
  mkdirSync(join(dir, "prompts"));
  temporaryDirs.push(dir);
  return dir;
}

function createContext(): {
  ctx: Context;
  definitions: CommandDefinition[];
  warnings: string[];
  disposers: Array<() => void>;
} {
  const definitions: CommandDefinition[] = [];
  const warnings: string[] = [];
  const disposers: Array<() => void> = [];
  const ctx = {
    commands: {
      register: vi.fn((definition: CommandDefinition) => {
        definitions.push(definition);
        return vi.fn();
      }),
    },
    logger: {
      warn: vi.fn((message: string) => warnings.push(message)),
    },
    effect: vi.fn((factory: () => Generator<() => void>) => {
      for (const disposer of factory()) disposers.push(disposer);
    }),
  } as unknown as Context;
  return { ctx, definitions, warnings, disposers };
}

describe("apply", () => {
  test("registers valid prompts, diagnoses bad files, and skips invalid command names", () => {
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
    const { ctx, definitions, warnings, disposers } = createContext();

    apply(ctx);

    expect(definitions.map((definition) => definition.name).sort()).toEqual(["fallback", "valid"]);
    const valid = definitions.find((definition) => definition.name === "valid");
    expect(valid).toMatchObject({
      description: "First line\nSecond: line\n",
      input: { hint: "topic: detail" },
    });
    expect(definitions.find((definition) => definition.name === "fallback")?.description).toBe(
      "First body line",
    );
    expect(warnings).toHaveLength(2);
    expect(warnings.join("\n")).toMatch(/cannot parse bad\.md/u);
    expect(warnings.join("\n")).toMatch(/empty prompt body in empty\.md/u);
    expect(disposers).toHaveLength(2);
  });

  test("steers an identified user message with rendered prompt text", () => {
    const agentDir = createAgentDir();
    writeFileSync(join(agentDir, "prompts", "valid.md"), "Hello ${1:-world}: ${@:2}\n");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const { ctx, definitions } = createContext();
    apply(ctx);
    const handler = definitions[0]?.handler;
    expect(handler).toBeDefined();
    const steer = vi.fn();

    const result = handler?.({
      agent: { steer } as never,
      commandId: "command-id" as never,
      rawInput: "Alice one two",
      signal: AbortSignal.timeout(1_000),
    });

    expect(result).toEqual({ kind: "success", text: 'Sent the pi prompt "valid".' });
    expect(steer).toHaveBeenCalledOnce();
    expect(steer.mock.calls[0]?.[0]).toMatchObject({
      id: expect.any(String),
      role: "user",
      source: { kind: "user" },
      content: [{ type: "text", text: "Hello Alice: one two\n" }],
    });
  });

  test("returns an error when substitution renders an empty prompt", () => {
    const agentDir = createAgentDir();
    writeFileSync(join(agentDir, "prompts", "empty-render.md"), "$1");
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
    const { ctx, definitions } = createContext();
    apply(ctx);

    const result = definitions[0]?.handler({
      agent: { steer: vi.fn() } as never,
      commandId: "command-id" as never,
      rawInput: "",
      signal: AbortSignal.timeout(1_000),
    });

    expect(result).toEqual({ kind: "error", text: "The prompt renders empty." });
  });

  test("warns and stays inactive when the prompts directory is missing", () => {
    const missing = join(tmpdir(), `missing-dsh-pi-prompts-${Date.now()}`);
    vi.stubEnv("PI_CODING_AGENT_DIR", missing);
    const { ctx, definitions, warnings } = createContext();

    apply(ctx);

    expect(definitions).toEqual([]);
    expect(warnings).toHaveLength(1);
    expect(warnings[0]).toContain(`cannot read ${join(missing, "prompts")}`);
  });
});
