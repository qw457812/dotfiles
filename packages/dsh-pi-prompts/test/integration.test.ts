import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Context } from "@deepseek-ai/cordis";
import AgentRegistry, { type Agent } from "@deepseek-ai/dsh-agent";
import CommandRuntime from "@deepseek-ai/dsh-commands";
import { createScope } from "@deepseek-ai/dsh-scope";
import SessionStore, { SessionId } from "@deepseek-ai/dsh-session";
import { afterEach, describe, expect, test, vi } from "vitest";
import * as PiPrompts from "../src/index.js";

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

describe("real DSH registries", () => {
  test("registers global and trusted project prompts in an existing agent scope", async () => {
    const agentDir = temporaryDir("dsh-pi-prompts-integration-agent-");
    const workspace = temporaryDir("dsh-pi-prompts-integration-workspace-");
    mkdirSync(join(agentDir, "prompts"));
    mkdirSync(join(workspace, ".pi", "prompts"), { recursive: true });
    writeFileSync(join(agentDir, "prompts", "global.md"), "Global prompt\n");
    writeFileSync(join(workspace, ".pi", "prompts", "project.md"), "Project prompt\n");
    writeFileSync(
      join(agentDir, "trust.json"),
      `${JSON.stringify({ [realpathSync(workspace)]: true })}\n`,
    );
    vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);

    const ctx = new Context();
    await ctx.plugin(SessionStore);
    await ctx.plugin(AgentRegistry);
    await ctx.plugin(CommandRuntime);
    const session = ctx.sessions.create(SessionId("pi-prompts-integration"), {
      meta: { cwd: workspace },
    });
    const agent = {
      id: session.id,
      session,
      status: "idle",
      steer: vi.fn(),
    } as unknown as Agent;
    const scope = createScope(ctx, agent);
    Object.defineProperty(scope.ctx, "agent", { value: agent, configurable: true });
    Object.assign(agent, { ctx: scope.ctx });
    ctx.agents.register(agent);

    const pluginFiber = ctx.plugin(PiPrompts);
    await pluginFiber;

    expect(ctx.commands.list(agent).map(({ name }) => name)).toEqual(["global", "project"]);

    await pluginFiber.dispose();
    expect(ctx.commands.list(agent)).toEqual([]);
    await ctx.root.fiber.dispose();
  });
});
