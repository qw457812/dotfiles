import { defineConfig } from "oxfmt";

export default defineConfig({
  ignorePatterns: [
    "package.json",
    "models-store.json",
    "prompts/",
    "skills/",
    "keybindings.json",
    "AGENTS.md",
    "extensions/answer.ts",
    "extensions/btw.ts",
    "extensions/files.ts",
    "extensions/goal.ts",
    "extensions/handoff.ts",
    "extensions/loop.ts",
    "extensions/notify.ts",
    "extensions/review.ts",
    "extensions/subagent.ts",
    "extensions/todos.ts",
    "extensions/tools.ts",
    "extensions/tps.ts",
    "extensions/trust-github-repos.ts",
  ],
});
