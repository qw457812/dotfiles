/**
 * Lazy-enable the pi-computer-use tool group.
 *
 * `@injaneity/pi-computer-use` registers eleven desktop/browser control tools and
 * relies on Pi's startup behavior, which activates every extension tool. This
 * extension keeps them registered but out of `pi.getActiveTools()` unless the
 * session proves it needs them, so a normal coding session never pays for the
 * tool schemas, prompt snippets, or guidelines.
 *
 * Enabling signals:
 * - The active branch contains a historical assistant `toolCall` for any group
 *   tool. `session_start` and `session_tree` re-evaluate this on restore.
 * - `/computer-use-on` enables the group explicitly for the current run.
 * - `--no-computer-use-lazy` opts the whole run out of the lazy policy. Pi
 *   activates extension tools at startup anyway, so honoring the flag means
 *   simply not removing them.
 *
 * Once enabled during a run, this extension never disables the group again
 * (one-way). A restored branch can show earlier computer-use calls, and hiding
 * the tools afterward would contradict that visible history. Disabling is a
 * user-initiated action owned by `/tools`, which rewrites the active set after
 * this extension's restore handlers run.
 *
 * The tools' execution behavior is unchanged; only their active-set membership
 * changes.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

/** Tools registered by `@injaneity/pi-computer-use`. Update when upstream adds tools. */
const COMPUTER_USE_TOOLS = [
  "find_roots",
  "observe_ui",
  "search_ui",
  "expand_ui",
  "inspect_ui",
  "act_ui",
  "read_text",
  "wait_for",
  "launch_browser",
  "navigate_browser",
  "evaluate_browser",
] as const;

const COMPUTER_USE_TOOL_SET = new Set<string>(COMPUTER_USE_TOOLS);

function branchHasComputerUseToolCall(ctx: ExtensionContext): boolean {
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message") continue;
    const message = entry.message;
    if (message.role !== "assistant" || !Array.isArray(message.content)) continue;

    for (const block of message.content) {
      if (block.type === "toolCall" && COMPUTER_USE_TOOL_SET.has(block.name)) return true;
    }
  }
  return false;
}

export default function (pi: ExtensionAPI): void {
  pi.registerFlag("no-computer-use-lazy", {
    description: "Keep the pi-computer-use tools active in every session",
    type: "boolean",
    default: false,
  });

  let computerUseToolsEnabled = false;

  function setComputerUseToolsEnabled(enabled: boolean): void {
    // Pi already activates every extension tool, so opt-out is a no-op.
    if (pi.getFlag("no-computer-use-lazy") === true) return;

    // One-way: a branch restore may not hide tools this run already exposed.
    if (!enabled && computerUseToolsEnabled) return;

    // Stay inert when the package is absent or all of its tools are filtered out.
    const registered = new Set(pi.getAllTools().map((tool) => tool.name));
    const groupTools = COMPUTER_USE_TOOLS.filter((name) => registered.has(name));
    if (groupTools.length === 0) return;

    const activeTools = new Set(pi.getActiveTools());
    const activeToolCountBefore = activeTools.size;

    if (enabled) {
      computerUseToolsEnabled = true;
      for (const name of groupTools) activeTools.add(name);
    } else {
      for (const name of groupTools) activeTools.delete(name);
    }

    if (activeTools.size !== activeToolCountBefore) pi.setActiveTools(Array.from(activeTools));
  }

  function restoreComputerUseTools(ctx: ExtensionContext): void {
    setComputerUseToolsEnabled(branchHasComputerUseToolCall(ctx));
  }

  pi.on("session_start", async (_event, ctx) => restoreComputerUseTools(ctx));
  pi.on("session_tree", async (_event, ctx) => restoreComputerUseTools(ctx));

  pi.registerCommand("computer-use-on", {
    description: "Enable the pi-computer-use tools for this run",
    handler: async (_args, ctx) => {
      if (pi.getFlag("no-computer-use-lazy") === true) {
        ctx.ui.notify("Computer-use tools are always enabled (--no-computer-use-lazy)", "info");
        return;
      }
      if (computerUseToolsEnabled) {
        ctx.ui.notify("Computer-use tools are already enabled", "info");
        return;
      }
      setComputerUseToolsEnabled(true);
      ctx.ui.notify("Computer-use tools enabled for this run", "info");
    },
  });
}
