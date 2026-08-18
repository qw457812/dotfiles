/**
 * Expose Pi agent prompts (`~/.pi/agent/prompts/*.md`) as dsh slash commands.
 *
 * Each prompt file becomes one command: the file stem is the command name,
 * `description` and `argument-hint` come from the file's YAML frontmatter.
 * Loading, argument parsing, and placeholder substitution mirror pi's
 * `prompt-templates.ts` exactly (quoted bash-style args; `$1`, `$@`,
 * `$ARGUMENTS`, `${N:-default}`, `${@:-default}`, `${@:N}`, `${@:N:L}`),
 * so a command behaves just like typing the same `/prompt args` in pi.
 * The rendered body is steered into the receiving agent as a user message.
 * @module dsh-plugin-pi-prompts
 * @ts-check
 */

import { randomUUID } from "node:crypto";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

/** @typedef {import("@deepseek-ai/cordis").Context} Context */

/**
 * One prompt file parsed into command registration metadata.
 * @typedef {{
 *   name: string;
 *   description: string;
 *   hint: string | undefined;
 *   body: string;
 * }} PiPrompt
 */

/**
 * The `commands` registry surface this plugin uses.
 * @typedef {{
 *   register(definition: {
 *     name: string;
 *     description: string;
 *     input?: { hint: string };
 *     handler(invocation: {
 *       agent: { steer(message: {
 *         id: string;
 *         role: "user";
 *         content: { type: "text"; text: string }[];
 *         source: { kind: "user" };
 *       }): void };
 *       rawInput: string;
 *     }): { kind: "success" | "error"; text: string };
 *   }): () => void;
 * }} CommandRegistry
 */

const name = "pi-prompts";
const inject = ["commands"];

/**
 * The effective prompts directory, mirroring pi's `getAgentDir()` +
 * `getPromptsDir()` in `packages/coding-agent/src/config.ts`:
 * `$PI_CODING_AGENT_DIR/prompts` when the env var is set (`~` expanded like
 * pi's `normalizePath`), otherwise `~/.pi/agent/prompts` (the default agent
 * dir with `configDir: ".pi"`).
 * @returns {string}
 */
function getPromptsDir() {
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

/** Valid command name: lowercase letters, digits, `_`, `-`. */
const NAME_PATTERN = /^[a-z0-9_-]+$/;

/**
 * Parse prompt-file frontmatter like pi's `parseFrontmatter`: content must
 * start with `---`, the closing fence is the next `\n---`, and the body is
 * everything after it, trimmed. Values are single-line `key: value` strings
 * with optional surrounding quotes.
 * @param {string} text - full file content.
 * @returns {{ meta: Record<string, string>, body: string }}
 */
function parsePromptFile(text) {
  const normalized = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  if (!normalized.startsWith("---")) return { meta: {}, body: normalized.trim() };
  const endIndex = normalized.indexOf("\n---", 3);
  if (endIndex === -1) return { meta: {}, body: normalized.trim() };
  /** @type {Record<string, string>} */
  const meta = {};
  for (const line of normalized.slice(4, endIndex).split("\n")) {
    const colon = line.indexOf(":");
    if (colon === -1) continue;
    const key = line.slice(0, colon).trim();
    let value = line.slice(colon + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (key !== "") meta[key] = value;
  }
  return { meta, body: normalized.slice(endIndex + 4).trim() };
}

/**
 * Fallback description like pi: the first non-empty body line, truncated to
 * 60 characters with an ellipsis.
 * @param {string} body
 * @returns {string}
 */
function describeFromBody(body) {
  const firstLine = body.split("\n").find((line) => line.trim());
  if (firstLine === undefined) return "";
  return firstLine.length > 60 ? `${firstLine.slice(0, 60)}...` : firstLine;
}

/**
 * Parse command arguments respecting quoted strings (bash-style), matching
 * pi's `parseCommandArgs`.
 * @param {string} argsString - raw text after the command name.
 * @returns {string[]}
 */
function parseCommandArgs(argsString) {
  /** @type {string[]} */
  const args = [];
  let current = "";
  /** @type {string | null} */
  let inQuote = null;
  for (let i = 0; i < argsString.length; i++) {
    const char = argsString[i];
    if (inQuote !== null) {
      if (char === inQuote) inQuote = null;
      else current += char;
    } else if (char === '"' || char === "'") {
      inQuote = char;
    } else if (/\s/.test(char)) {
      if (current !== "") {
        args.push(current);
        current = "";
      }
    } else {
      current += char;
    }
  }
  if (current !== "") args.push(current);
  return args;
}

/**
 * Substitute argument placeholders in template content, matching pi's
 * `substituteArgs` grammar:
 * - `$1`, `$2`, ... positional args (missing → empty)
 * - `$@`, `$ARGUMENTS` all args joined
 * - `${N:-default}` positional arg with default when missing/empty
 * - `${@:-default}`, `${ARGUMENTS:-default}` all args with default when empty
 * - `${@:N}` / `${@:N:L}` bash-style slicing (1-indexed, `0` treated as `1`)
 *
 * Single-pass replacement; argument and default values are never recursively
 * substituted.
 * @param {string} content - prompt body.
 * @param {string[]} args - parsed command arguments.
 * @returns {string}
 */
function substituteArgs(content, args) {
  const allArgs = args.join(" ");
  return content.replace(
    /\$\{(\d+|ARGUMENTS|@):-([^}]*)\}|\$\{@:(\d+)(?::(\d+))?\}|\$(ARGUMENTS|@|\d+)/g,
    (_match, defaultTarget, defaultValue, sliceStart, sliceLength, simple) => {
      if (defaultTarget !== undefined) {
        const value =
          defaultTarget === "@" || defaultTarget === "ARGUMENTS"
            ? allArgs
            : args[parseInt(defaultTarget, 10) - 1];
        return value ? value : defaultValue;
      }
      if (sliceStart !== undefined) {
        let start = parseInt(sliceStart, 10) - 1;
        if (start < 0) start = 0;
        if (sliceLength !== undefined) {
          const length = parseInt(sliceLength, 10);
          return args.slice(start, start + length).join(" ");
        }
        return args.slice(start).join(" ");
      }
      if (simple === "ARGUMENTS" || simple === "@") return allArgs;
      return args[parseInt(simple, 10) - 1] ?? "";
    },
  );
}

/**
 * Register one slash command for one prompt file.
 * @param {Context} ctx
 * @param {PiPrompt} prompt
 * @returns {() => void} the exact effect disposer.
 */
function registerPrompt(ctx, prompt) {
  /** @type {CommandRegistry} */
  const commands = ctx.get("commands");
  return commands.register({
    name: prompt.name,
    description: prompt.description,
    ...(prompt.hint !== undefined ? { input: { hint: prompt.hint } } : {}),
    handler: ({ agent, rawInput }) => {
      const text = substituteArgs(prompt.body, parseCommandArgs(rawInput));
      if (text === "") return { kind: "error", text: "The prompt renders empty." };
      agent.steer({
        id: randomUUID(),
        role: "user",
        content: [{ type: "text", text }],
        source: { kind: "user" },
      });
      return { kind: "success", text: `Sent the pi prompt "${prompt.name}".` };
    },
  });
}

/**
 * Load every `*.md` prompt from the prompts directory (following symlinks,
 * like pi) and register one slash command per file. Unreadable files are
 * skipped with a warning; an unreadable directory registers nothing.
 * @param {Context} ctx - the plugin context.
 */
function apply(ctx) {
  const promptsDir = getPromptsDir();

  let entries;
  try {
    entries = readdirSync(promptsDir, { withFileTypes: true });
  } catch (error) {
    ctx.logger.warn(`pi-prompts: cannot read ${promptsDir}: ${String(error)}`);
    return;
  }

  /** @type {PiPrompt[]} */
  const prompts = [];
  for (const entry of entries) {
    let isFile = entry.isFile();
    if (entry.isSymbolicLink()) {
      try {
        isFile = statSync(join(promptsDir, entry.name)).isFile();
      } catch {
        continue; // broken symlink
      }
    }
    if (!isFile || !entry.name.endsWith(".md")) continue;
    const stem = entry.name.slice(0, -3);
    if (!NAME_PATTERN.test(stem)) continue;
    let text;
    try {
      text = readFileSync(join(promptsDir, entry.name), "utf8");
    } catch (error) {
      ctx.logger.warn(`pi-prompts: cannot read ${entry.name}: ${String(error)}`);
      continue;
    }
    const { meta, body } = parsePromptFile(text);
    if (body === "") {
      ctx.logger.warn(`pi-prompts: empty prompt body in ${entry.name}; skipped`);
      continue;
    }
    prompts.push({
      name: stem,
      description: meta.description || describeFromBody(body),
      hint: meta["argument-hint"] || undefined,
      body,
    });
  }

  ctx.effect(function* () {
    for (const prompt of prompts) {
      yield registerPrompt(ctx, prompt);
    }
  });
}

export { apply, inject, name };
