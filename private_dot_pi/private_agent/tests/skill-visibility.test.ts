import {
  formatSkillsForPrompt,
  type BeforeAgentStartEvent,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
  type Skill,
} from "@earendil-works/pi-coding-agent";
import { expect, it, vi } from "vitest";
import skillVisibility from "../extensions/skill-visibility.js";

function fixture() {
  let handler: ((event: BeforeAgentStartEvent, ctx: ExtensionContext) => unknown) | undefined;
  let command: Parameters<ExtensionAPI["registerCommand"]>[1] | undefined;
  skillVisibility({
    on: (_event: string, callback: typeof handler) => {
      handler = callback;
    },
    registerCommand: (_name: string, options: typeof command) => {
      command = options;
    },
  } as unknown as ExtensionAPI);

  const originalSkills = [
    { name: "ponytail-review", disableModelInvocation: false },
    { name: "commit", disableModelInvocation: false },
  ].map((skill) => ({
    ...skill,
    description: "test",
    filePath: `/test/${skill.name}/SKILL.md`,
    baseDir: `/test/${skill.name}`,
    sourceInfo: {
      path: `/test/${skill.name}/SKILL.md`,
      source: "test",
      scope: "user" as const,
      origin: "top-level" as const,
    },
  })) satisfies Skill[];
  const options = {
    cwd: "/test",
    skills: originalSkills,
    selectedTools: ["read"],
    sections: {} as Record<string, string>,
    forceSystemPrompt: undefined as string | undefined,
  };
  const render = () =>
    options.forceSystemPrompt ??
    [
      options.selectedTools.some((tool) => tool === "read" || tool === "bash")
        ? formatSkillsForPrompt(options.skills)
        : "",
      ...Object.values(options.sections),
    ].join("\n");
  const event = {
    type: "before_agent_start",
    prompt: "test",
    get systemPrompt() {
      return render();
    },
    systemPromptOptions: options,
  } as BeforeAgentStartEvent;
  const ctx = {
    mode: "print",
    getSystemPrompt: render,
    ui: { notify: vi.fn() },
  } as unknown as ExtensionCommandContext;

  return {
    originalSkills,
    options,
    ctx,
    render,
    emit: () => handler!(event, ctx),
    diff: () => command!.handler("diff", ctx),
  };
}

it("hides skills without forcing a prompt that masks later ponytail sections", async () => {
  const f = fixture();
  const result = await f.emit();
  expect(result).toBeUndefined();
  expect(f.options.forceSystemPrompt).toBeUndefined();
  expect(f.options.skills[0].disableModelInvocation).toBe(true);
  expect(f.options.skills[1].disableModelInvocation).toBe(false);
  expect(f.originalSkills[0].disableModelInvocation).toBe(false);
  expect(f.ctx.ui.notify).not.toHaveBeenCalled();

  // Ponytail 5 adds its section after the local visibility handler.
  f.options.sections.ponytail = "PONYTAIL MODE ACTIVE";
  expect(f.render()).toContain("PONYTAIL MODE ACTIVE");
  expect(f.render()).not.toContain("<name>ponytail-review</name>");
  expect(f.render()).toContain("<name>commit</name>");
});

it("preserves a ponytail section added before the visibility handler", async () => {
  const f = fixture();
  f.options.sections.ponytail = "PONYTAIL MODE ACTIVE";

  const result = await f.emit();

  expect(result).toBeUndefined();
  expect(f.options.forceSystemPrompt).toBeUndefined();
  expect(f.options.sections.ponytail).toBe("PONYTAIL MODE ACTIVE");
  expect(f.render()).toContain("PONYTAIL MODE ACTIVE");
  expect(f.render()).not.toContain("<name>ponytail-review</name>");
  expect(f.render()).toContain("<name>commit</name>");
  expect(f.ctx.ui.notify).not.toHaveBeenCalled();
});

it("reports when an opaque forced prompt prevents hiding a skill", async () => {
  const f = fixture();
  f.options.forceSystemPrompt = f.render();
  await f.emit();
  expect(f.ctx.ui.notify).toHaveBeenCalledWith(
    "skill-visibility: failed to hide ponytail-review. Run /skill-visibility diff.",
    "warning",
  );
  expect(f.render()).toContain("<name>ponytail-review</name>");
});

it("does not report missing skills when no file reader is selected", async () => {
  const f = fixture();
  f.options.selectedTools = [];
  await f.emit();
  expect(f.ctx.ui.notify).not.toHaveBeenCalled();
  expect(f.render()).not.toContain("<available_skills>");
});

it("does not invent a prompt diff before the first turn", async () => {
  const f = fixture();
  await f.diff();
  expect(f.ctx.ui.notify).toHaveBeenCalledWith(
    "System prompt diff: unavailable until the first turn",
    "info",
  );
  expect(f.options.skills).toBe(f.originalSkills);
});

it("shows the actual rendered prompt diff from the latest turn", async () => {
  const f = fixture();
  await f.emit();
  await f.diff();
  expect(f.ctx.ui.notify).toHaveBeenLastCalledWith(
    expect.stringContaining("-    <name>ponytail-review</name>"),
    "info",
  );
  expect(f.ctx.ui.notify).toHaveBeenLastCalledWith(
    expect.stringContaining("--- system-prompt.before"),
    "info",
  );
});

it("reports no diff when structured changes do not affect a forced prompt", async () => {
  const f = fixture();
  f.options.forceSystemPrompt = f.render();
  await f.emit();
  await f.diff();
  expect(f.ctx.ui.notify).toHaveBeenLastCalledWith(
    "System prompt diff: (none; extension made no changes)",
    "info",
  );
});
