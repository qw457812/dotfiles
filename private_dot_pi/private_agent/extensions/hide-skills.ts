/**
 * Local `disable-model-invocation: true` for selected package skills.
 *
 * Hides them from the system prompt while keeping `/skill:<name>` usable.
 * Use `/hidden-skills` to inspect configured skills and `/hidden-skills diff` to show
 * the exact prompt change from the latest turn.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// `disable-model-invocation: true` for skills from pi packages
const HIDDEN_SKILL_NAMES = new Set([
  // git:github.com/mitsuhiko/agent-stuff
  "frontend-design",
  "web-browser",
  // git:github.com/addyosmani/agent-skills
  "source-driven-development",
  // git:github.com/DietrichGebert/ponytail
  "ponytail",
  "ponytail-audit",
  "ponytail-debt",
  "ponytail-review",
]);
type PromptPair = { before: string; after: string };

export default function (pi: ExtensionAPI) {
  let lastPromptPair: PromptPair | undefined;
  let warned = false;

  pi.on("before_agent_start", async (event, ctx) => {
    const systemPrompt = stripSkillBlocks(event.systemPrompt);
    lastPromptPair = { before: event.systemPrompt, after: systemPrompt };

    warned = warnOnUnexpectedPromptChange(ctx, event.systemPrompt, systemPrompt, warned);

    if (systemPrompt === event.systemPrompt) return;

    return { systemPrompt };
  });

  pi.registerCommand("hidden-skills", {
    description: "Show skills hidden from the system prompt",
    getArgumentCompletions(prefix) {
      return "diff".startsWith(prefix) ? [{ value: "diff", label: "diff" }] : null;
    },
    handler: async (args, ctx) => showHiddenSkills(ctx, args.trim() === "diff", lastPromptPair),
  });
}

function stripSkillBlocks(systemPrompt: string): string {
  return systemPrompt.replace(skillBlockRegex(), (block, name: string) =>
    HIDDEN_SKILL_NAMES.has(name) ? "" : block,
  );
}

function skillBlockRegex(): RegExp {
  // Mirrors pi's formatSkillsForPrompt skill block shape:
  // https://github.com/earendil-works/pi/blob/8e1900666f3cb83c281297d8f787fae6ee2bd0e6/packages/coding-agent/src/core/skills.ts#L351-L355
  return /\n  <skill>\n    <name>([^<]+)<\/name>\n    <description>[\s\S]*?<\/description>\n    <location>[\s\S]*?<\/location>\n  <\/skill>/g;
}

function warnOnUnexpectedPromptChange(
  ctx: Pick<ExtensionCommandContext, "ui">,
  before: string,
  after: string,
  warned: boolean,
): boolean {
  if (warned) return true;

  const beforeNames = skillNamesInPrompt(before);
  const afterNames = skillNamesInPrompt(after);
  const stillVisible = [...afterNames].filter((name) => HIDDEN_SKILL_NAMES.has(name));
  const unexpectedlyRemoved = [...beforeNames].filter(
    (name) => !afterNames.has(name) && !HIDDEN_SKILL_NAMES.has(name),
  );
  const warnings: string[] = [];

  if (stillVisible.length > 0) warnings.push(`failed to remove ${stillVisible.join(", ")}`);
  if (unexpectedlyRemoved.length > 0)
    warnings.push(`unexpectedly removed ${unexpectedlyRemoved.join(", ")}`);
  if (warnings.length === 0) return false;

  ctx.ui.notify(`hide-skills: ${warnings.join("; ")}. Run /hidden-skills diff.`, "warning");
  return true;
}

function skillNamesInPrompt(systemPrompt: string): Set<string> {
  const names = new Set<string>();
  for (const match of systemPrompt.matchAll(skillBlockRegex())) {
    names.add(match[1]);
  }
  return names;
}

function buildPromptDiff(before: string, after: string): string {
  if (before === after) return "";

  const dir = mkdtempSync(join(tmpdir(), "pi-hidden-skills-"));
  const beforePath = join(dir, "system-prompt.before");
  const afterPath = join(dir, "system-prompt.after");

  try {
    writeFileSync(beforePath, before);
    writeFileSync(afterPath, after);
    return cleanDiffHeaders(runDiff(beforePath, afterPath));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function runDiff(beforePath: string, afterPath: string): string {
  return execForStdout("git", [
    "diff",
    "--no-index",
    "--no-color",
    "--patience",
    "--",
    beforePath,
    afterPath,
  ]);
}

function execForStdout(command: string, args: string[]): string {
  try {
    return execFileSync(command, args, { encoding: "utf8" });
  } catch (error) {
    const stdout = (error as { stdout?: Buffer | string }).stdout;
    return Buffer.isBuffer(stdout) ? stdout.toString("utf8") : (stdout ?? "");
  }
}

function cleanDiffHeaders(diff: string): string {
  return diff
    .split("\n")
    .filter((line) => !line.startsWith("diff --git ") && !line.startsWith("index "))
    .join("\n")
    .replace(/^--- .*system-prompt\.before.*$/m, "--- system-prompt.before")
    .replace(/^\+\+\+ .*system-prompt\.after.*$/m, "+++ system-prompt.after")
    .trimEnd();
}

function showHiddenSkills(
  ctx: ExtensionCommandContext,
  showDiff: boolean,
  lastPromptPair: PromptPair | undefined,
): void {
  if (showDiff) {
    const before = lastPromptPair?.before ?? ctx.getSystemPrompt();
    const after = lastPromptPair?.after ?? stripSkillBlocks(before);
    ctx.ui.notify(
      buildPromptDiff(before, after) || "System prompt diff: (none; extension made no changes)",
      "info",
    );
    return;
  }

  const skills = ctx.getSystemPromptOptions().skills ?? [];
  const configured = [...HIDDEN_SKILL_NAMES];
  const loaded = skills.filter((skill) => HIDDEN_SKILL_NAMES.has(skill.name));
  const loadedNames = loaded.map((skill) => skill.name);
  const missingNames = configured.filter((name) => !loadedNames.includes(name));
  const alreadyHidden = loaded
    .filter((skill) => skill.disableModelInvocation)
    .map((skill) => skill.name);
  const lines = [
    `Hidden skills: ${loaded.length}/${configured.length} loaded`,
    loadedNames.join(", "),
  ];

  if (missingNames.length > 0) lines.push(`Missing: ${missingNames.join(", ")}`);
  if (alreadyHidden.length > 0)
    lines.push(`Already hidden by SKILL.md: ${alreadyHidden.join(", ")}`);

  lines.push("", "Diff: /hidden-skills diff · Manual invoke still works: /skill:<name>");

  ctx.ui.notify(lines.join("\n"), "info");
}
