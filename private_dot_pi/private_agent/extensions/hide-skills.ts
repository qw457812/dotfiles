/**
 * Local model-invocation visibility overrides for selected package skills.
 *
 * Hides selected visible skills from the system prompt while keeping `/skill:<name>` usable.
 * Also reveals selected `disable-model-invocation: true` skills to the model without
 * changing the package source.
 * Use `/hidden-skills` to inspect configured skills and `/hidden-skills diff` to open
 * the exact prompt change from the latest turn.
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

const HIDDEN_SKILLS = [
  // git:github.com/mitsuhiko/agent-stuff
  "frontend-design",
  "web-browser",
  "github",
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

const REVEALED_SKILLS: string[] = [
  // // git:github.com/mattpocock/skills
  // "teach",
  // "writing-great-skills",
];

type PromptPair = { before: string; after: string };
type StripResult = { prompt: string; removed: string[] };
type RevealResult = { prompt: string; added: string[]; available: string[] };

// Mirrors pi's formatSkillsForPrompt skill block shape:
// https://github.com/earendil-works/pi/blob/8e1900666f3cb83c281297d8f787fae6ee2bd0e6/packages/coding-agent/src/core/skills.ts#L351-L355
const SKILL_BLOCK_RE =
  /\n  <skill>\n    <name>([^<]+)<\/name>\n    <description>[\s\S]*?<\/description>\n    <location>[\s\S]*?<\/location>\n  <\/skill>/g;

export default function (pi: ExtensionAPI) {
  let lastPromptPair: PromptPair | undefined;
  let checked = false;

  pi.on("before_agent_start", async (event, ctx) => {
    const skills = event.systemPromptOptions.skills ?? [];
    const stripped = stripHiddenSkills(event.systemPrompt);
    const revealed = revealDisabledSkills(
      stripped.prompt,
      skills,
      event.systemPromptOptions.selectedTools?.includes("read") ?? false,
    );

    lastPromptPair = { before: event.systemPrompt, after: revealed.prompt };
    if (!checked) {
      checked = true;
      checkDrift(ctx, skills, stripped.removed, revealed.available);
    }

    if (revealed.prompt === event.systemPrompt) return;
    return { systemPrompt: revealed.prompt };
  });

  pi.registerCommand("hidden-skills", {
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
        after: revealDisabledSkills(
          stripHiddenSkills(currentPrompt).prompt,
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

function stripHiddenSkills(systemPrompt: string): StripResult {
  const removed: string[] = [];
  const strippedPrompt = systemPrompt.replace(SKILL_BLOCK_RE, (block, name: string) => {
    if (!HIDDEN_SKILLS.includes(name)) return block;
    removed.push(name);
    return "";
  });

  return { prompt: pruneEmptySkillsSection(strippedPrompt), removed };
}

function revealDisabledSkills(
  systemPrompt: string,
  skills: Skill[],
  canAppendSkillsSection: boolean,
): RevealResult {
  const disabledSkillsToReveal = skills.filter(
    (skill) => REVEALED_SKILLS.includes(skill.name) && skill.disableModelInvocation,
  );
  const existingNames = getPromptSkillNames(systemPrompt);
  const missingSkills = disabledSkillsToReveal.filter((skill) => !existingNames.has(skill.name));
  const added = missingSkills.map((skill) => skill.name);

  let prompt = systemPrompt;
  if (missingSkills.length > 0) {
    if (prompt.includes("</available_skills>")) {
      const blocks = formatSkillBlocks(missingSkills);
      if (blocks) {
        prompt = prompt.replace("</available_skills>", `${blocks}\n</available_skills>`);
      }
    } else if (canAppendSkillsSection) {
      prompt = insertSkillsSection(prompt, formatModelInvocableSkillsForPrompt(missingSkills));
    }
  }

  const availableNames = getPromptSkillNames(prompt);
  const available = disabledSkillsToReveal
    .filter((skill) => availableNames.has(skill.name))
    .map((skill) => skill.name);
  return { prompt, added, available };
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

  // https://github.com/earendil-works/pi/blob/1ab2899800b1d7120cd6188e6eead24459a725b1/packages/coding-agent/src/core/system-prompt.ts#L169
  const currentDateIndex = systemPrompt.lastIndexOf("\nCurrent date:");
  if (currentDateIndex === -1) return systemPrompt + skillsSection;

  return (
    systemPrompt.slice(0, currentDateIndex) + skillsSection + systemPrompt.slice(currentDateIndex)
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
  removed: string[],
  revealed: string[],
): void {
  const expectedHidden = skills
    .filter((skill) => HIDDEN_SKILLS.includes(skill.name) && !skill.disableModelInvocation)
    .map((skill) => skill.name);
  const missingHidden = expectedHidden.filter((name) => !removed.includes(name));
  const extraHidden = removed.filter((name) => !expectedHidden.includes(name));
  const expectedRevealed = skills
    .filter((skill) => REVEALED_SKILLS.includes(skill.name) && skill.disableModelInvocation)
    .map((skill) => skill.name);
  const missingRevealed = expectedRevealed.filter((name) => !revealed.includes(name));
  const lines: string[] = [];

  if (missingHidden.length > 0) lines.push(`failed to strip ${missingHidden.join(", ")}`);
  if (extraHidden.length > 0) lines.push(`unexpectedly stripped ${extraHidden.join(", ")}`);
  if (missingRevealed.length > 0) lines.push(`failed to reveal ${missingRevealed.join(", ")}`);
  if (lines.length === 0) return;

  ctx.ui.notify(`hide-skills: ${lines.join("; ")}. Run /hidden-skills diff.`, "warning");
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
    const filePath = join(tmpdir(), `pi-extension-pager-hide-skills-${Date.now()}.diff`);
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
  const hiddenLoaded = skills.filter((skill) => HIDDEN_SKILLS.includes(skill.name));
  const hiddenLoadedNames = hiddenLoaded.map((skill) => skill.name);
  const hiddenMissingNames = HIDDEN_SKILLS.filter((name) => !hiddenLoadedNames.includes(name));
  const alreadyHidden = hiddenLoaded
    .filter((skill) => skill.disableModelInvocation)
    .map((skill) => skill.name);

  const revealedLoaded = skills.filter((skill) => REVEALED_SKILLS.includes(skill.name));
  const revealedLoadedNames = revealedLoaded.map((skill) => skill.name);
  const revealedMissingNames = REVEALED_SKILLS.filter(
    (name) => !revealedLoadedNames.includes(name),
  );
  const revealedByExtension = revealedLoaded
    .filter((skill) => skill.disableModelInvocation)
    .map((skill) => skill.name);
  const alreadyVisible = revealedLoaded
    .filter((skill) => !skill.disableModelInvocation)
    .map((skill) => skill.name);

  const lines = [
    `Hidden skills: ${hiddenLoaded.length}/${HIDDEN_SKILLS.length} loaded`,
    hiddenLoadedNames.join(", "),
    `Revealed disabled skills: ${revealedLoaded.length}/${REVEALED_SKILLS.length} loaded`,
    revealedLoadedNames.join(", "),
  ];

  if (hiddenMissingNames.length > 0) lines.push(`Missing hidden: ${hiddenMissingNames.join(", ")}`);
  if (alreadyHidden.length > 0)
    lines.push(`Already hidden by SKILL.md: ${alreadyHidden.join(", ")}`);
  if (revealedMissingNames.length > 0)
    lines.push(`Missing revealed: ${revealedMissingNames.join(", ")}`);
  if (revealedByExtension.length > 0)
    lines.push(`Revealed by extension: ${revealedByExtension.join(", ")}`);
  if (alreadyVisible.length > 0)
    lines.push(`Already visible by SKILL.md: ${alreadyVisible.join(", ")}`);

  lines.push("", "Diff: /hidden-skills diff · Manual invoke still works: /skill:<name>");
  return lines.join("\n");
}
