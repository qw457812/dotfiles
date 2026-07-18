/**
 * Skill visibility overrides for package skills.
 *
 * Pi normally derives model visibility from each skill's SKILL.md frontmatter:
 * `disable-model-invocation: true` keeps a skill out of `<available_skills>`, while
 * still allowing explicit `/skill:<name>` use. This extension adds a local layer on
 * top of that without editing package sources.
 *
 * Configure:
 * - PROMPT_HIDDEN_SKILLS: loaded, normally-visible skills to remove from the prompt.
 * - PROMPT_REVEALED_SKILLS: loaded, normally-hidden skills to add back to the prompt.
 *
 * Commands:
 * - /skill-visibility: show configured/loaded/active status.
 * - /skill-visibility diff: open the exact prompt rewrite from the latest turn.
 */

// See also: https://github.com/earendil-works/pi/blob/3e5ad67e0f325d4888f82f9b82966218eb4407f5/packages/coding-agent/examples/extensions/prompt-customizer.ts

import {
  formatSkillsForPrompt,
  generateUnifiedPatch,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
  type Skill,
} from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PROMPT_HIDDEN_SKILLS = [
  // git:github.com/mitsuhiko/agent-stuff
  "frontend-design",
  "web-browser",
  "github",
  // git:github.com/mattpocock/skills
  "resolving-merge-conflicts",
  // git:github.com/addyosmani/agent-skills
  "source-driven-development",
  // git:github.com/DietrichGebert/ponytail
  "ponytail",
  "ponytail-audit",
  "ponytail-debt",
  "ponytail-review",
  // git:github.com/hugohe3/ppt-master
  "ppt-master",
];

const PROMPT_REVEALED_SKILLS: string[] = [
  // // git:github.com/mattpocock/skills
  // "teach",
  // "writing-great-skills",
];

const COMMAND = "skill-visibility";

type PromptPair = { before: string; after: string };
type PromptHideResult = { prompt: string; removed: string[] };
type PromptRevealResult = { prompt: string; available: string[] };
type PromptVisibilityResult = { prompt: string; hidden: string[]; revealed: string[] };

// Mirrors pi's formatSkillsForPrompt skill block shape:
// https://github.com/earendil-works/pi/blob/8e1900666f3cb83c281297d8f787fae6ee2bd0e6/packages/coding-agent/src/core/skills.ts#L351-L355
const SKILL_BLOCK_RE =
  /\n  <skill>\n    <name>([^<]+)<\/name>\n    <description>[\s\S]*?<\/description>\n    <location>[\s\S]*?<\/location>\n  <\/skill>/g;

export default function (pi: ExtensionAPI) {
  let lastPromptPair: PromptPair | undefined;
  let checked = false;

  pi.on("before_agent_start", async (event, ctx) => {
    const skills = event.systemPromptOptions.skills ?? [];
    const result = applySkillVisibilityOverrides(
      event.systemPrompt,
      skills,
      event.systemPromptOptions.selectedTools?.includes("read") ?? false,
    );

    lastPromptPair = { before: event.systemPrompt, after: result.prompt };
    if (!checked) {
      checked = true;
      checkDrift(ctx, skills, result.hidden, result.revealed);
    }

    if (result.prompt === event.systemPrompt) return;
    return { systemPrompt: result.prompt };
  });

  pi.registerCommand(COMMAND, {
    description: "Show skill prompt visibility overrides",
    getArgumentCompletions(prefix: string) {
      const items = [
        {
          value: "diff",
          label: "diff",
          description: "open the system prompt change from the latest turn",
        },
      ];
      const filtered = items.filter((item) => item.value.startsWith(prefix.trimStart()));
      return filtered.length > 0 ? filtered : null;
    },
    handler: async (args, ctx) => {
      if (args.trim() !== "diff") {
        ctx.ui.notify(buildStatus(ctx.getSystemPromptOptions().skills ?? []), "info");
        return;
      }

      const currentPrompt = ctx.getSystemPrompt();
      const { before, after } = lastPromptPair ?? {
        before: currentPrompt,
        after: applySkillVisibilityOverrides(
          currentPrompt,
          ctx.getSystemPromptOptions().skills ?? [],
          ctx.getSystemPromptOptions().selectedTools?.includes("read") ?? false,
        ).prompt,
      };
      if (before === after) {
        ctx.ui.notify("System prompt diff: (none; extension made no changes)", "info");
        return;
      }

      const diff = generateUnifiedPatch("system-prompt", before, after)
        .replace("--- system-prompt\n", "--- system-prompt.before\n")
        .replace("+++ system-prompt\n", "+++ system-prompt.after\n");
      await openDiffInEditor(ctx, diff);
    },
  });
}

function applySkillVisibilityOverrides(
  systemPrompt: string,
  skills: Skill[],
  canAppendSkillsSection: boolean,
): PromptVisibilityResult {
  const hidden = hidePromptSkills(systemPrompt);
  const revealed = revealPromptSkills(hidden.prompt, skills, canAppendSkillsSection);

  return {
    prompt: revealed.prompt,
    hidden: hidden.removed,
    revealed: revealed.available,
  };
}

function hidePromptSkills(systemPrompt: string): PromptHideResult {
  const removed: string[] = [];
  const strippedPrompt = systemPrompt.replace(SKILL_BLOCK_RE, (block, name: string) => {
    if (!PROMPT_HIDDEN_SKILLS.includes(name)) return block;
    removed.push(name);
    return "";
  });

  return { prompt: pruneEmptySkillsSection(strippedPrompt), removed };
}

function revealPromptSkills(
  systemPrompt: string,
  skills: Skill[],
  canAppendSkillsSection: boolean,
): PromptRevealResult {
  const disabledSkillsToReveal = skills.filter(
    (skill) => PROMPT_REVEALED_SKILLS.includes(skill.name) && skill.disableModelInvocation,
  );
  const existingNames = getPromptSkillNames(systemPrompt);
  const missingSkills = disabledSkillsToReveal.filter((skill) => !existingNames.has(skill.name));

  let prompt = systemPrompt;
  if (missingSkills.length > 0) {
    if (prompt.includes("</available_skills>")) {
      prompt = insertSkillBlocks(prompt, missingSkills);
    } else if (canAppendSkillsSection) {
      prompt = insertSkillsSection(prompt, formatModelInvocableSkillsForPrompt(missingSkills));
    }
  }

  const availableNames = getPromptSkillNames(prompt);
  const available = disabledSkillsToReveal
    .filter((skill) => availableNames.has(skill.name))
    .map((skill) => skill.name);
  return { prompt, available };
}

function insertSkillBlocks(systemPrompt: string, skills: Skill[]): string {
  const blocks = formatSkillBlocks(skills);
  if (!blocks) return systemPrompt;
  return systemPrompt.replace("</available_skills>", `${blocks}\n</available_skills>`);
}

function getPromptSkillNames(systemPrompt: string): Set<string> {
  return new Set(Array.from(systemPrompt.matchAll(SKILL_BLOCK_RE), (match) => match[1]));
}

function pruneEmptySkillsSection(systemPrompt: string): string {
  if (getPromptSkillNames(systemPrompt).size > 0) return systemPrompt;

  // https://github.com/earendil-works/pi/blob/c100620bf447349ae7a4866bc1cb6757cc9f67c4/packages/coding-agent/src/core/skills.ts#L335-L361
  const endMarker = "</available_skills>";
  const endIndex = systemPrompt.indexOf(endMarker);
  if (endIndex === -1) return systemPrompt;

  const startMarker =
    "\n\nThe following skills provide specialized instructions for specific tasks.";
  const startIndex = systemPrompt.lastIndexOf(startMarker, endIndex);
  if (startIndex === -1) return systemPrompt;

  return systemPrompt.slice(0, startIndex) + systemPrompt.slice(endIndex + endMarker.length);
}

function insertSkillsSection(systemPrompt: string, skillsSection: string): string {
  if (!skillsSection) return systemPrompt;

  // https://github.com/earendil-works/pi/blob/818d67457cdd6b60bce6b121d16b23141c252dd8/packages/coding-agent/src/core/system-prompt.ts#L159
  const workingDirectoryIndex = systemPrompt.lastIndexOf("\nCurrent working directory:");
  if (workingDirectoryIndex === -1) return systemPrompt + skillsSection;

  return (
    systemPrompt.slice(0, workingDirectoryIndex) +
    skillsSection +
    systemPrompt.slice(workingDirectoryIndex)
  );
}

function formatSkillBlocks(skills: Skill[]): string {
  return Array.from(
    formatModelInvocableSkillsForPrompt(skills).matchAll(SKILL_BLOCK_RE),
    (match) => match[0],
  )
    .join("")
    .replace(/^\n/, "");
}

function formatModelInvocableSkillsForPrompt(skills: Skill[]): string {
  return formatSkillsForPrompt(
    skills.map((skill) => ({ ...skill, disableModelInvocation: false })),
  );
}

function checkDrift(
  ctx: Pick<ExtensionContext, "ui">,
  skills: Skill[],
  hidden: string[],
  revealed: string[],
): void {
  const expectedHidden = skills
    .filter((skill) => PROMPT_HIDDEN_SKILLS.includes(skill.name) && !skill.disableModelInvocation)
    .map((skill) => skill.name);
  const missingHidden = expectedHidden.filter((name) => !hidden.includes(name));
  const extraHidden = hidden.filter((name) => !expectedHidden.includes(name));
  const expectedRevealed = skills
    .filter((skill) => PROMPT_REVEALED_SKILLS.includes(skill.name) && skill.disableModelInvocation)
    .map((skill) => skill.name);
  const missingRevealed = expectedRevealed.filter((name) => !revealed.includes(name));
  const extraRevealed = revealed.filter((name) => !expectedRevealed.includes(name));
  const lines: string[] = [];

  if (missingHidden.length > 0) lines.push(`failed to hide ${missingHidden.join(", ")}`);
  if (extraHidden.length > 0) lines.push(`unexpected hidden skills: ${extraHidden.join(", ")}`);
  if (missingRevealed.length > 0) lines.push(`failed to reveal ${missingRevealed.join(", ")}`);
  if (extraRevealed.length > 0)
    lines.push(`unexpected revealed skills: ${extraRevealed.join(", ")}`);
  if (lines.length === 0) return;

  ctx.ui.notify(`skill-visibility: ${lines.join("; ")}. Run /${COMMAND} diff.`, "warning");
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
    const filePath = join(tmpdir(), `pi-extension-pager-skill-visibility-${Date.now()}.diff`);
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
  const hiddenLoaded = skills.filter((skill) => PROMPT_HIDDEN_SKILLS.includes(skill.name));
  const hiddenLoadedNames = hiddenLoaded.map((skill) => skill.name);
  const hiddenMissingNames = PROMPT_HIDDEN_SKILLS.filter(
    (name) => !hiddenLoadedNames.includes(name),
  );
  const hiddenByExtension = hiddenLoaded
    .filter((skill) => !skill.disableModelInvocation)
    .map((skill) => skill.name);
  const alreadyHidden = hiddenLoaded
    .filter((skill) => skill.disableModelInvocation)
    .map((skill) => skill.name);

  const revealedLoaded = skills.filter((skill) => PROMPT_REVEALED_SKILLS.includes(skill.name));
  const revealedLoadedNames = revealedLoaded.map((skill) => skill.name);
  const revealedMissingNames = PROMPT_REVEALED_SKILLS.filter(
    (name) => !revealedLoadedNames.includes(name),
  );
  const revealedByExtension = revealedLoaded
    .filter((skill) => skill.disableModelInvocation)
    .map((skill) => skill.name);
  const alreadyVisible = revealedLoaded
    .filter((skill) => !skill.disableModelInvocation)
    .map((skill) => skill.name);

  const lines = [
    "Skill visibility overrides",
    "",
    ...formatStatusSection({
      title: "Hide from prompt",
      configuredCount: PROMPT_HIDDEN_SKILLS.length,
      loadedCount: hiddenLoaded.length,
      activeNames: hiddenByExtension,
      missingNames: hiddenMissingNames,
      noopLabel: "Already hidden by SKILL.md",
      noopNames: alreadyHidden,
    }),
    "",
    ...formatStatusSection({
      title: "Reveal to prompt",
      configuredCount: PROMPT_REVEALED_SKILLS.length,
      loadedCount: revealedLoaded.length,
      activeNames: revealedByExtension,
      missingNames: revealedMissingNames,
      noopLabel: "Already visible by SKILL.md",
      noopNames: alreadyVisible,
    }),
    "",
    `Diff: /${COMMAND} diff · Manual invoke still works: /skill:<name>`,
  ];

  return lines.join("\n");
}

function formatStatusSection(options: {
  title: string;
  configuredCount: number;
  loadedCount: number;
  activeNames: string[];
  missingNames: string[];
  noopLabel: string;
  noopNames: string[];
}): string[] {
  const lines = [
    `${options.title}: ${options.activeNames.length} active / ${options.loadedCount} loaded / ${options.configuredCount} configured`,
    `  Active: ${options.activeNames.length > 0 ? options.activeNames.join(", ") : "(none)"}`,
  ];

  if (options.missingNames.length > 0) {
    lines.push(`  Missing: ${options.missingNames.join(", ")}`);
  }
  if (options.noopNames.length > 0) {
    lines.push(`  ${options.noopLabel}: ${options.noopNames.join(", ")}`);
  }

  return lines;
}
