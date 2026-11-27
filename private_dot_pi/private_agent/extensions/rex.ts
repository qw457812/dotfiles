/**
 * Rex Extension
 *
 * Adds a <rex> system prompt section with Rex's session context when Pi runs
 * inside a Rex terminal. This mirrors the SessionStart hook that
 * `rex skill setup` installs for Claude Code and Codex; Rex reports Pi's hook
 * as unsupported, so it is injected here instead.
 *
 * Ref: https://github.com/michalvavra/agents/blob/f9bb349a958ea4a12316655827b5794661da3abe/agents/pi/extensions/rex.ts
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const IS_REX = Boolean(process.env.REX_BLOCK);
const REX_PROMPT_SECTION = "rex";
const REX_SESSION_START_TIMEOUT_MS = 3000;

export default function rexExtension(pi: ExtensionAPI): void {
  if (IS_REX) {
    pi.registerMcpServer("superlogical", {
      url: "https://www.superlogical.com/rex/community-mcp",
    });
  }

  let rexContext = "";

  pi.on("session_start", async (_event, ctx) => {
    rexContext = "";
    if (!IS_REX) return;

    const result = await pi.exec(
      "rex",
      ["__internal", "session-start", "--agent", "pi", "--feature-session-naming=false"],
      { cwd: ctx.cwd, timeout: REX_SESSION_START_TIMEOUT_MS },
    );
    if (!result.killed && result.code === 0) {
      rexContext = result.stdout.trim();
      return;
    }
    if (ctx.hasUI) {
      const reason = result.killed
        ? "timed out"
        : result.stderr.trim() || `exited with ${result.code}`;
      ctx.ui.notify(`rex: no session context for the system prompt (${reason})`, "warning");
    }
  });

  pi.on("before_agent_start", (event) => {
    if (rexContext) event.systemPromptOptions.sections[REX_PROMPT_SECTION] = rexContext;
  });
}
