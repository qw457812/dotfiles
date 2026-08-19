import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { parsePromptFile } from "./prompt-templates.js";

/** One validated Pi prompt template ready for command registration. */
export interface PiPrompt {
  name: string;
  description: string;
  hint: string | undefined;
  body: string;
  filePath: string;
}

/** dsh command names must begin with a lowercase letter. */
const NAME_PATTERN = /^[a-z][a-z0-9_-]*$/u;

/** Derive Pi's fallback description from the first non-empty body line. */
function describeFromBody(body: string): string {
  const firstLine = body.split("\n").find((line) => line.trim());
  if (firstLine === undefined) return "";
  return firstLine.length > 60 ? `${firstLine.slice(0, 60)}...` : firstLine;
}

/**
 * Load every direct `*.md` child of one Pi prompts directory.
 * Missing directories are empty; other directory failures are reported by the caller.
 */
export function loadPromptsFromDir(
  promptsDir: string,
  warn: (message: string) => void,
): PiPrompt[] {
  let entries;
  try {
    entries = readdirSync(promptsDir, { withFileTypes: true });
  } catch (error) {
    if (typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT") {
      return [];
    }
    throw error;
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

    const filePath = join(promptsDir, entry.name);
    let text: string;
    try {
      text = readFileSync(filePath, "utf8");
    } catch (error) {
      warn(`cannot read ${filePath}: ${String(error)}`);
      continue;
    }

    let parsed: ReturnType<typeof parsePromptFile>;
    try {
      parsed = parsePromptFile(text);
    } catch (error) {
      warn(`cannot parse ${filePath}: ${String(error)}`);
      continue;
    }

    const { meta, body } = parsed;
    if (body.trim() === "") {
      warn(`empty prompt body in ${filePath}; skipped`);
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
      filePath,
    });
  }
  return prompts;
}

/** Merge project before global prompts, matching Pi's name-collision precedence. */
export function mergePrompts(
  projectPrompts: readonly PiPrompt[],
  globalPrompts: readonly PiPrompt[],
  warn: (message: string) => void,
): PiPrompt[] {
  const merged = new Map<string, PiPrompt>();
  for (const prompt of [...projectPrompts, ...globalPrompts]) {
    const winner = merged.get(prompt.name);
    if (winner === undefined) {
      merged.set(prompt.name, prompt);
    } else {
      warn(
        `prompt "/${prompt.name}" from ${prompt.filePath} skipped; ${winner.filePath} has precedence`,
      );
    }
  }
  return [...merged.values()];
}
