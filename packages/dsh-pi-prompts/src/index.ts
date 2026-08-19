/**
 * Expose Pi prompt templates as DeepSeek Harness slash commands.
 * @module @qw457812/dsh-pi-prompts
 */

import type { Context } from "@deepseek-ai/cordis";
import type { Agent } from "@deepseek-ai/dsh-agent";
import type { CommandDefinition } from "@deepseek-ai/dsh-commands";
import { createUserMessage } from "@deepseek-ai/dsh-llm";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadPromptsFromDir, mergePrompts, type PiPrompt } from "./discovery.js";
import { isProjectTrusted } from "./project-trust.js";
import { parseCommandArgs, substituteArgs } from "./prompt-templates.js";

export const name = "pi-prompts";
export const inject = ["agents", "commands"];

type OwnerCleanup = () => void | Promise<void>;

/** Resolve Pi's effective agent configuration directory. */
function getAgentDir(): string {
  const envDir = process.env.PI_CODING_AGENT_DIR;
  if (envDir !== undefined && envDir !== "") {
    if (envDir === "~") return homedir();
    if (envDir.startsWith("~/")) return join(homedir(), envDir.slice(2));
    if (envDir.startsWith("file://")) return fileURLToPath(envDir);
    return resolve(envDir);
  }
  return join(homedir(), ".pi", "agent");
}

/** Build one slash command backed by a prompt template. */
function promptDefinition(prompt: PiPrompt): CommandDefinition {
  return {
    name: prompt.name,
    description: prompt.description,
    ...(prompt.hint === undefined ? {} : { input: { hint: prompt.hint } }),
    handler: ({ agent, rawInput }) => {
      const text = substituteArgs(prompt.body, parseCommandArgs(rawInput));
      if (text === "") return { kind: "error", text: "The prompt renders empty." };
      agent.steer(
        createUserMessage({
          content: [{ type: "text", text }],
          source: { kind: "user" },
        }),
      );
      return { kind: "success", text: `Sent the pi prompt "${prompt.name}".` };
    },
  };
}

/** Load one directory without letting a filesystem failure abort agent publication. */
function loadDirectory(ctx: Context, directory: string): PiPrompt[] {
  try {
    return loadPromptsFromDir(directory, (message) => {
      ctx.logger.warn(`pi-prompts: ${message}`);
    });
  } catch (error) {
    ctx.logger.warn(`pi-prompts: cannot read ${directory}: ${String(error)}`);
    return [];
  }
}

/** Resolve the effective prompt set for one root agent. */
function loadAgentPrompts(ctx: Context, agent: Agent, agentDir: string): PiPrompt[] {
  const globalPrompts = loadDirectory(ctx, join(agentDir, "prompts"));
  const cwd = agent.session.header.cwd;
  if (cwd === undefined) return globalPrompts;

  let trusted = false;
  try {
    trusted = isProjectTrusted(agentDir, cwd);
  } catch (error) {
    ctx.logger.warn(`pi-prompts: cannot resolve project trust for ${cwd}: ${String(error)}`);
  }
  const projectPrompts = trusted ? loadDirectory(ctx, join(cwd, ".pi", "prompts")) : [];
  return mergePrompts(projectPrompts, globalPrompts, (message) => {
    ctx.logger.warn(`pi-prompts: ${message}`);
  });
}

/** Register the effective templates in one agent-scoped command layer. */
function registerAgentPrompts(ctx: Context, agent: Agent, agentDir: string): OwnerCleanup {
  const prompts = loadAgentPrompts(ctx, agent, agentDir);
  const registrations: Array<() => void> = [];

  let cleanup: OwnerCleanup = () => undefined;
  cleanup = agent.ctx.effect(() => {
    for (const prompt of prompts) {
      if (ctx.commands.find(agent, prompt.name) !== undefined) {
        ctx.logger.warn(
          `pi-prompts: prompt "/${prompt.name}" from ${prompt.filePath} skipped; a command already owns that name`,
        );
        continue;
      }
      try {
        registrations.push(agent.ctx.commands.register(promptDefinition(prompt)));
      } catch (error) {
        ctx.logger.warn(
          `pi-prompts: cannot register "/${prompt.name}" from ${prompt.filePath}: ${String(error)}`,
        );
      }
    }
    return () => {
      for (const dispose of registrations.reverse()) dispose();
      registrations.length = 0;
    };
  }, "pi-prompts.agent()") as OwnerCleanup;
  return cleanup;
}

/** Load and own Pi prompt commands for every live root agent. */
export function apply(ctx: Context): void {
  const agentDir = getAgentDir();
  const installations = new Map<Agent, OwnerCleanup>();
  let stopping = false;

  const install = (agent: Agent): void => {
    if (stopping || installations.has(agent) || !ctx.agents.roots().includes(agent)) return;
    let cleanup: OwnerCleanup = () => undefined;
    try {
      cleanup = registerAgentPrompts(ctx, agent, agentDir);
      installations.set(agent, async () => {
        try {
          await cleanup();
        } finally {
          installations.delete(agent);
        }
      });
    } catch (error) {
      ctx.logger.warn(
        `pi-prompts: cannot install prompts for agent "${agent.id}": ${String(error)}`,
      );
    }
  };

  ctx.effect(() => {
    const stopCreated = ctx.on("agent/created", ({ agent }) => {
      install(agent);
    });
    const stopDisposed = ctx.on("agent/disposed", ({ agent }) => {
      const cleanup = installations.get(agent);
      if (cleanup !== undefined) {
        void Promise.resolve(cleanup()).catch((error: unknown) => {
          ctx.logger.warn(`pi-prompts: cannot clean up agent "${agent.id}": ${String(error)}`);
        });
      }
    });
    for (const agent of ctx.agents.roots()) install(agent);

    return async () => {
      stopping = true;
      stopCreated();
      stopDisposed();
      const cleanups = [...installations.values()];
      installations.clear();
      await Promise.allSettled(cleanups.map((cleanup) => Promise.resolve(cleanup())));
    };
  }, "pi-prompts.lifecycle()");
}
