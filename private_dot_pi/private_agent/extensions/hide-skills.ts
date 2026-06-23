/**
 * Local `disable-model-invocation: true` for selected package skills.
 *
 * Hides them from the system prompt while keeping `/skill:<name>` usable.
 * Use `/hidden-skills` to inspect configured skills and `/hidden-skills diff` to open
 * the exact prompt change from the latest turn.
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { execFileSync, spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const HIDDEN_SKILLS = [
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
];
type PromptPair = { before: string; after: string };
type Skill = { name: string; disableModelInvocation: boolean };

export default function (pi: ExtensionAPI) {
  let lastPromptPair: PromptPair | undefined;
  let warned = false;

  pi.on("before_agent_start", async (event, ctx) => {
    const nextPrompt = stripHiddenSkills(event.systemPrompt);
    lastPromptPair = { before: event.systemPrompt, after: nextPrompt };
    warned = warnOnceOnUnexpectedChange(ctx, lastPromptPair, warned);

    if (nextPrompt === event.systemPrompt) return;
    return { systemPrompt: nextPrompt };
  });

  pi.registerCommand("hidden-skills", {
    description: "Show skills hidden from the system prompt",
    getArgumentCompletions(prefix) {
      return "diff".startsWith(prefix) ? [{ value: "diff", label: "diff" }] : null;
    },
    handler: async (args, ctx) => {
      if (args.trim() === "diff") {
        const before = lastPromptPair?.before ?? ctx.getSystemPrompt();
        const promptPair = lastPromptPair ?? { before, after: stripHiddenSkills(before) };
        const diff = buildPromptDiff(promptPair);
        if (!diff) ctx.ui.notify("System prompt diff: (none; extension made no changes)", "info");
        else await openDiffInEditor(ctx, diff);
        return;
      }

      ctx.ui.notify(buildStatus(ctx.getSystemPromptOptions().skills ?? []), "info");
    },
  });
}

function stripHiddenSkills(systemPrompt: string): string {
  return systemPrompt.replace(skillBlockRegex(), (block, name: string) =>
    HIDDEN_SKILLS.includes(name) ? "" : block,
  );
}

function skillBlockRegex(): RegExp {
  // Mirrors pi's formatSkillsForPrompt skill block shape:
  // https://github.com/earendil-works/pi/blob/8e1900666f3cb83c281297d8f787fae6ee2bd0e6/packages/coding-agent/src/core/skills.ts#L351-L355
  return /\n  <skill>\n    <name>([^<]+)<\/name>\n    <description>[\s\S]*?<\/description>\n    <location>[\s\S]*?<\/location>\n  <\/skill>/g;
}

function warnOnceOnUnexpectedChange(
  ctx: Pick<ExtensionCommandContext, "ui">,
  promptPair: PromptPair,
  warned: boolean,
): boolean {
  if (warned) return true;

  const beforeNames = skillNamesInPrompt(promptPair.before);
  const afterNames = skillNamesInPrompt(promptPair.after);
  const stillVisible = [...afterNames].filter((name) => HIDDEN_SKILLS.includes(name));
  const unexpectedlyRemoved = [...beforeNames].filter(
    (name) => !afterNames.has(name) && !HIDDEN_SKILLS.includes(name),
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
  for (const match of systemPrompt.matchAll(skillBlockRegex())) names.add(match[1]);
  return names;
}

async function openDiffInEditor(ctx: ExtensionCommandContext, diff: string): Promise<void> {
  // Based on pi's external editor flow:
  // https://github.com/earendil-works/pi/blob/8e1900666f3cb83c281297d8f787fae6ee2bd0e6/packages/coding-agent/src/modes/interactive/components/extension-editor.ts#L113-L155
  // and the extension example for releasing/restoring the TUI around an inherited stdio process:
  // https://github.com/earendil-works/pi/blob/8e1900666f3cb83c281297d8f787fae6ee2bd0e6/packages/coding-agent/examples/extensions/interactive-shell.ts#L155-L179
  const editorCmd = process.env.VISUAL || process.env.EDITOR;
  if (ctx.mode !== "tui" || !editorCmd) {
    ctx.ui.notify(diff, "info");
    return;
  }

  await ctx.ui.custom<void>((tui, _theme, _kb, done) => {
    const filePath = join(tmpdir(), `pi-hidden-skills-${Date.now()}.diff`);
    let stopped = false;

    void (async () => {
      try {
        writeFileSync(filePath, diff);
        tui.stop();
        stopped = true;

        const [editor, ...editorArgs] = editorCmd.split(" ");
        process.stdout.write(
          `Opening ${filePath} in ${editorCmd}\nPi will resume when the editor exits.\n`,
        );
        await new Promise<void>((resolve) => {
          const child = spawn(editor, [...editorArgs, filePath], {
            stdio: "inherit",
            shell: process.platform === "win32",
            env: process.env,
          });
          child.on("error", () => resolve());
          child.on("close", () => resolve());
        });
      } finally {
        rmSync(filePath, { force: true });
        if (stopped) {
          tui.start();
          tui.requestRender(true);
        }
        done();
      }
    })();

    return { render: () => [], invalidate: () => {} };
  });
}

function buildStatus(skills: Skill[]): string {
  const loaded = skills.filter((skill) => HIDDEN_SKILLS.includes(skill.name));
  const loadedNames = loaded.map((skill) => skill.name);
  const missingNames = HIDDEN_SKILLS.filter((name) => !loadedNames.includes(name));
  const alreadyHidden = loaded
    .filter((skill) => skill.disableModelInvocation)
    .map((skill) => skill.name);
  const lines = [
    `Hidden skills: ${loaded.length}/${HIDDEN_SKILLS.length} loaded`,
    loadedNames.join(", "),
  ];

  if (missingNames.length > 0) lines.push(`Missing: ${missingNames.join(", ")}`);
  if (alreadyHidden.length > 0)
    lines.push(`Already hidden by SKILL.md: ${alreadyHidden.join(", ")}`);

  lines.push("", "Diff: /hidden-skills diff · Manual invoke still works: /skill:<name>");
  return lines.join("\n");
}

function buildPromptDiff({ before, after }: PromptPair): string {
  if (before === after) return "";

  const dir = mkdtempSync(join(tmpdir(), "pi-hidden-skills-"));
  const beforePath = join(dir, "system-prompt.before");
  const afterPath = join(dir, "system-prompt.after");

  try {
    writeFileSync(beforePath, before);
    writeFileSync(afterPath, after);
    try {
      return execFileSync(
        "git",
        ["diff", "--no-index", "--no-color", "--patience", "--", beforePath, afterPath],
        { encoding: "utf8" },
      );
    } catch (error) {
      const stdout = (error as { stdout?: Buffer | string }).stdout;
      const diff = Buffer.isBuffer(stdout) ? stdout.toString("utf8") : (stdout ?? "");
      return diff
        .split("\n")
        .filter((line) => !line.startsWith("diff --git ") && !line.startsWith("index "))
        .join("\n")
        .replace(/^--- .*system-prompt\.before.*$/m, "--- system-prompt.before")
        .replace(/^\+\+\+ .*system-prompt\.after.*$/m, "+++ system-prompt.after")
        .trimEnd();
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
