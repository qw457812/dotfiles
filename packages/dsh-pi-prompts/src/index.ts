/**
 * Expose Pi prompt templates as DeepSeek Harness slash commands.
 * @module @qw457812/dsh-pi-prompts
 */

import { readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Context } from "@deepseek-ai/cordis";
import type { CommandDefinition } from "@deepseek-ai/dsh-commands";
import { createUserMessage } from "@deepseek-ai/dsh-llm";
import { parseCommandArgs, parsePromptFile, substituteArgs } from "./prompt-templates.js";

interface PiPrompt {
  name: string;
  description: string;
  hint: string | undefined;
  body: string;
}

export const name = "pi-prompts";
export const inject = ["commands"];

/** Resolve Pi's effective prompts directory. */
function getPromptsDir(): string {
  const envDir = process.env.PI_CODING_AGENT_DIR;
  if (envDir !== undefined && envDir !== "") {
    let dir = envDir;
    if (dir === "~") dir = homedir();
    else if (dir.startsWith("~/")) dir = join(homedir(), dir.slice(2));
    else if (dir.startsWith("file://")) dir = fileURLToPath(dir);
    return join(dir, "prompts");
  }
  return join(homedir(), ".pi", "agent", "prompts");
}

/** dsh command names must begin with a lowercase letter. */
const NAME_PATTERN = /^[a-z][a-z0-9_-]*$/u;

/** Derive Pi's fallback description from the first non-empty body line. */
function describeFromBody(body: string): string {
  const firstLine = body.split("\n").find((line) => line.trim());
  if (firstLine === undefined) return "";
  return firstLine.length > 60 ? `${firstLine.slice(0, 60)}...` : firstLine;
}

/** Register one slash command and return its exact disposer. */
function registerPrompt(ctx: Context, prompt: PiPrompt): () => void {
  const definition: CommandDefinition = {
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
  return ctx.commands.register(definition);
}

/** Load every direct `*.md` child and register one command per valid template. */
export function apply(ctx: Context): void {
  const promptsDir = getPromptsDir();

  let entries;
  try {
    entries = readdirSync(promptsDir, { withFileTypes: true });
  } catch (error) {
    ctx.logger.warn(`pi-prompts: cannot read ${promptsDir}: ${String(error)}`);
    return;
  }

  const prompts: PiPrompt[] = [];
  for (const entry of entries) {
    let isFile = entry.isFile();
    if (entry.isSymbolicLink()) {
      try {
        isFile = statSync(join(promptsDir, entry.name)).isFile();
      } catch {
        continue;
      }
    }
    if (!isFile || !entry.name.endsWith(".md")) continue;
    const stem = entry.name.slice(0, -3);
    if (!NAME_PATTERN.test(stem)) continue;

    let text: string;
    try {
      text = readFileSync(join(promptsDir, entry.name), "utf8");
    } catch (error) {
      ctx.logger.warn(`pi-prompts: cannot read ${entry.name}: ${String(error)}`);
      continue;
    }

    let parsed: ReturnType<typeof parsePromptFile>;
    try {
      parsed = parsePromptFile(text);
    } catch (error) {
      ctx.logger.warn(`pi-prompts: cannot parse ${entry.name}: ${String(error)}`);
      continue;
    }

    const { meta, body } = parsed;
    if (body.trim() === "") {
      ctx.logger.warn(`pi-prompts: empty prompt body in ${entry.name}; skipped`);
      continue;
    }
    const description = meta.description;
    const hint = meta["argument-hint"];
    prompts.push({
      name: stem,
      description:
        typeof description === "string" && description !== ""
          ? description
          : describeFromBody(body),
      hint: typeof hint === "string" && hint !== "" ? hint : undefined,
      body,
    });
  }

  ctx.effect(function* () {
    for (const prompt of prompts) yield registerPrompt(ctx, prompt);
  });
}
