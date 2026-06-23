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

  pi.on("before_agent_start", async (event) => {
    const systemPrompt = stripSkillBlocks(event.systemPrompt);
    lastPromptPair = { before: event.systemPrompt, after: systemPrompt };
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
  return /\n  <skill>\n    <name>([^<]+)<\/name>\n    <description>[\s\S]*?<\/description>\n    <location>[\s\S]*?<\/location>\n  <\/skill>/g;
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
  return (
    execForStdout("git", [
      "diff",
      "--no-index",
      "--no-color",
      "--patience",
      "--",
      beforePath,
      afterPath,
    ]) || execForStdout("diff", ["-u", beforePath, afterPath])
  );
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
  const skills = ctx.getSystemPromptOptions().skills ?? [];
  const loaded = skills.filter((skill) => HIDDEN_SKILL_NAMES.has(skill.name));
  const alreadyHidden = loaded
    .filter((skill) => skill.disableModelInvocation)
    .map((skill) => skill.name);
  const lines = [
    "Configured hidden skills:",
    `  names: ${[...HIDDEN_SKILL_NAMES].join(", ")}`,
    "",
    loaded.length > 0
      ? `Currently matched: ${loaded.map((skill) => skill.name).join(", ")}`
      : "Currently matched: (none)",
  ];

  if (alreadyHidden.length > 0)
    lines.push(`Already hidden by SKILL.md: ${alreadyHidden.join(", ")}`);

  if (showDiff) {
    const before = lastPromptPair?.before ?? ctx.getSystemPrompt();
    const after = lastPromptPair?.after ?? stripSkillBlocks(before);
    const diff = buildPromptDiff(before, after);
    lines.push(
      "",
      diff ? "System prompt diff:" : "System prompt diff: (none; extension made no changes)",
      diff,
    );
  }

  lines.push(
    "",
    "Use /hidden-skills diff to show the actual system prompt diff.",
    "These skills remain manually invokable with /skill:<name>; only system-prompt visibility is removed.",
  );

  ctx.ui.notify(lines.join("\n"), "info");
}
