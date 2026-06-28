/**
 * Local `disable-model-invocation: true` for selected package skills.
 *
 * Hides them from the system prompt while keeping `/skill:<name>` usable.
 * Use `/hidden-skills` to inspect configured skills and `/hidden-skills diff` to open
 * the exact prompt change from the latest turn.
 */

// See also: https://github.com/earendil-works/pi/blob/3e5ad67e0f325d4888f82f9b82966218eb4407f5/packages/coding-agent/examples/extensions/prompt-customizer.ts

import {
  generateUnifiedPatch,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
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
];

type PromptPair = { before: string; after: string };
type Skill = { name: string; disableModelInvocation: boolean };
type StripResult = { prompt: string; removed: string[] };

// Mirrors pi's formatSkillsForPrompt skill block shape:
// https://github.com/earendil-works/pi/blob/8e1900666f3cb83c281297d8f787fae6ee2bd0e6/packages/coding-agent/src/core/skills.ts#L351-L355
const SKILL_BLOCK_RE =
  /\n  <skill>\n    <name>([^<]+)<\/name>\n    <description>[\s\S]*?<\/description>\n    <location>[\s\S]*?<\/location>\n  <\/skill>/g;

export default function (pi: ExtensionAPI) {
  let lastPromptPair: PromptPair | undefined;
  let checked = false;

  pi.on("before_agent_start", async (event, ctx) => {
    const stripped = stripHiddenSkills(event.systemPrompt);

    lastPromptPair = { before: event.systemPrompt, after: stripped.prompt };
    if (!checked) {
      checked = true;
      checkDrift(ctx, event.systemPromptOptions.skills ?? [], stripped.removed);
    }

    if (stripped.prompt === event.systemPrompt) return;
    return { systemPrompt: stripped.prompt };
  });

  pi.registerCommand("hidden-skills", {
    description: "Show skills hidden from the system prompt",
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
        after: stripHiddenSkills(currentPrompt).prompt,
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
  const prompt = systemPrompt.replace(SKILL_BLOCK_RE, (block, name: string) => {
    if (!HIDDEN_SKILLS.includes(name)) return block;
    removed.push(name);
    return "";
  });

  return { prompt, removed };
}

function checkDrift(ctx: Pick<ExtensionContext, "ui">, skills: Skill[], removed: string[]): void {
  const expected = skills
    .filter((skill) => HIDDEN_SKILLS.includes(skill.name) && !skill.disableModelInvocation)
    .map((skill) => skill.name);
  const missing = expected.filter((name) => !removed.includes(name));
  const extra = removed.filter((name) => !expected.includes(name));
  const lines: string[] = [];

  if (missing.length > 0) lines.push(`failed to strip ${missing.join(", ")}`);
  if (extra.length > 0) lines.push(`unexpectedly stripped ${extra.join(", ")}`);
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
