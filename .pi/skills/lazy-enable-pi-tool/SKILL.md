---
name: lazy-enable-pi-tool
description: Lazy-enable a pi extension tool from branch history or confirmed command conditions.
disable-model-invocation: true
---

# lazy-enable-pi-tool

Convert a pi extension tool from always-active to **lazy-enabled**: the tool is
registered, but it only enters `pi.getActiveTools()` when a branch signal or a
confirmed command condition proves the session needs it.

**One-way** means the extension may disable the tool only before it has enabled
it in the current run. Once enabled, the extension must not remove it again: a
restored branch can show the agent that it previously used this tool, and hiding
that tool afterward makes the visible history contradict the current tool list.

## Steps

1. **Negotiate the enabling policy.** Before editing code, discuss with the
   user which signals should enable the tool. Treat these as design choices, not
   defaults:

   - Session state in `ctx.sessionManager.getBranch()` custom entries, as in
     `extensions/goal.ts`.
   - Historical assistant tool calls, by scanning message entries for
     `block.type === "toolCall" && block.name === "<tool>"`, as in
     `extensions/todos.ts`.
   - Command paths, such as `/todos` or `/goal`, and the exact condition within
     each command that should enable the tool for the current run. The condition
     may be command entry, a branch in the command, an explicit user choice
     inside the command, a state transition, or no command condition at all.

   Recommend the smallest policy that proves the session needs the tool, then
   ask one question at a time until every enabling path and rejected signal is
   settled. If branch history contains this tool's tool call, apply **one-way**.

   Completion criterion: the user has confirmed the restore signals, any command
   conditions that enable the tool, and every rejected signal; every restore path
   with this tool in branch history applies **one-way**; a short policy summary
   has been written before code edits begin.

2. **Add a one-way active-tool helper.** Inside the extension factory, keep a
   boolean owned by the extension and mutate active tools through one helper:

   ```ts
   let exampleToolEnabled = false;

   function setExampleToolEnabled(enabled: boolean): void {
     if (!enabled && exampleToolEnabled) return;

     const activeTools = new Set(pi.getActiveTools());
     const activeToolCountBefore = activeTools.size;

     if (enabled) {
       exampleToolEnabled = true;
       activeTools.add("example");
     } else {
       activeTools.delete("example");
     }

     if (activeTools.size !== activeToolCountBefore) {
       pi.setActiveTools(Array.from(activeTools));
     }
   }
   ```

   The guard implements **one-way**.

   Completion criterion: all `setActiveTools` writes for this tool go through
   this helper, and enabling preserves every other active tool.

3. **Restore from branch navigation.** On `session_start` and `session_tree`,
   evaluate the branch signal and pass it to the helper:

   ```ts
   function restoreExampleTool(ctx: ExtensionContext): void {
     setExampleToolEnabled(branchHasExampleSignal(ctx));
   }

   pi.on("session_start", async (_event, ctx) => restoreExampleTool(ctx));

   pi.on("session_tree", async (_event, ctx) => restoreExampleTool(ctx));
   ```

   Completion criterion: restoring a branch with the signal enables the tool and
   applies **one-way**; restoring a branch without the signal disables it only if
   this extension has not already enabled it during the current run.

4. **Implement the confirmed command conditions.** For each command or UI path,
   enable the tool only under the condition the user confirmed. Some commands
   enable immediately, some enable only under a later branch, and some never
   enable tools themselves:

   ```ts
   pi.registerCommand("example", {
     handler: async (args, ctx) => {
       // existing command behavior
       if (shouldEnableExampleTool) setExampleToolEnabled(true);
     },
   });
   ```

   Do not add command-triggered enabling for paths or states the user did not
   approve.

   Completion criterion: every confirmed command condition enables the tool for
   subsequent agent turns in the same run, and no unconfirmed command path or
   state does.

5. **Document the policy.** Add a short top-level comment explaining what enables
   the tool and why restored branches that already used the tool keep it enabled.

   Completion criterion: the docs state the enabling signals, and the tool's
   execution behavior is unchanged; only when it appears in active tools changes.

## References

- `../../../private_dot_pi/private_agent/extensions/goal.ts` — custom session
  state signal plus one-way lazy enable.
- `../../../private_dot_pi/private_agent/extensions/todos.ts` — historical
  tool-call signal plus command-triggered enable.
