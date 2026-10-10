/**
 * Bash accidental-operation gate, not a security boundary.
 *
 * /gate                       Status and usage.
 * /gate git [on|off]           Control the existing Git confirmation rules.
 * /gate jev [on|off]           Semantic auto-approval (default ON).
 * /gate log                   Latest 20 decision summaries on the current branch.
 * Both switches are instance-local and reset to ON on /reload.
 *
 * Only calls matching the existing literal AST rules reach Jev. No operation category
 * is categorically excluded from auto-approval. Full commands and the latest ordinary user
 * message are sent to typesafe/jev-latest WITHOUT redaction; never tool output/history.
 * Missing authorization, oversized inputs and classification failures ask the user;
 * ask without UI blocks. Parser exceptions retain the existing warn-and-allow behavior.
 *
 * Coverage is unchanged: dynamic names, aliases, functions, wrappers (env, command,
 * xargs, shell -c), eval strings, expansions and filesystem state are not resolved.
 * Temporary-directory deletion exemptions remain. Bash checks handle tool_call,
 * including nested calls through codemode, not user_bash.
 * This entry also registers manual write/edit path and SQL guards.
 * dirty-repo-guard.ts owns dirty-repo reminders.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withBashTree } from "../../lib/bash-parser.ts";
import { confirm, confirmationResult } from "./confirmation.ts";
import pathGuard from "./path-guard.ts";
import sqlGuard from "./sql-guard.ts";
import { approvalRules, RULE_LABELS } from "./policy.ts";
import {
  GATE_MODEL,
  QUESTION_VERSION,
  REASON_LABELS,
  judgeCommand,
  type GateJudgment,
} from "./jev.ts";
import { latestUserIntent } from "./intent.ts";
import { GATE_ENTRY, showLog, type GateRecord, type Outcome } from "./log.ts";

export { GATE_ENTRY } from "./log.ts";
const USAGE = "Usage: /gate git [on|off] | jev [on|off] | log";

export default function (pi: ExtensionAPI) {
  pathGuard(pi);
  sqlGuard(pi);

  let gitEnabled = true;
  let jevEnabled = true;
  let lifecycle = new AbortController();

  const invalidate = () => {
    lifecycle.abort();
    lifecycle = new AbortController();
  };
  pi.on("session_before_switch", invalidate);
  pi.on("session_before_tree", invalidate);
  pi.on("session_shutdown", invalidate);
  pi.on("session_start", invalidate);

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const command = (event.input as { command?: string }).command ?? "";
    // Later tool_call handlers may otherwise change the command after it was approved.
    // They may still adjust unrelated options; command rewriting must happen before Gate.
    Object.defineProperty(event.input, "command", {
      value: command,
      writable: false,
      configurable: false,
      enumerable: true,
    });
    if (!command.trim()) return;

    const lifetime = lifecycle.signal;
    const signal = ctx.signal ? AbortSignal.any([lifetime, ctx.signal]) : lifetime;
    const sessionId = ctx.sessionManager.getSessionId();
    const user = latestUserIntent(ctx.sessionManager.getBranch());
    const sameAuthorization = () =>
      !lifetime.aborted &&
      ctx.sessionManager.getSessionId() === sessionId &&
      latestUserIntent(ctx.sessionManager.getBranch())?.id === user?.id;
    const current = () => !signal.aborted && sameAuthorization();
    const rules = await withBashTree(command, (root) => approvalRules(root, gitEnabled)).catch(
      () => {
        if (ctx.hasUI)
          ctx.ui.notify("Permission Gate: command checks skipped (parser failure)", "warning");
        return [];
      },
    );
    if (!rules.length) return;

    const started = Date.now();
    const classified = jevEnabled;
    let judgment: GateJudgment = { action: "ask", reason: "disabled" };
    if (classified) {
      judgment = await judgeCommand(ctx.modelRegistry, command, user?.text ?? "", ctx.cwd, signal);
    }
    const durationMs = Date.now() - started;
    const record = (outcome: Outcome) => {
      // Never append an old operation's entry to a replacement session/branch.
      if (!classified || lifetime.aborted || ctx.sessionManager.getSessionId() !== sessionId)
        return;
      pi.appendEntry<GateRecord>(GATE_ENTRY, {
        version: 1,
        questionVersion: QUESTION_VERSION,
        timestamp: new Date().toISOString(),
        model: `${GATE_MODEL.provider}/${GATE_MODEL.id}`,
        rules,
        judgment,
        durationMs,
        outcome,
      });
    };
    const cancelled = () => {
      judgment = { action: "cancelled", reason: "cancelled" };
      record("cancelled");
      return confirmationResult("cancelled");
    };
    if (!current() || judgment.action === "cancelled") return cancelled();
    if (judgment.action === "allow") {
      record("auto-approved");
      return;
    }
    const outcome = await confirm(
      pi,
      {
        ...ctx,
        signal,
        abort: () => {
          if (current()) ctx.abort();
        },
      },
      "🔐 Allow this command?",
      `Rules: ${rules.map((rule) => RULE_LABELS[rule]).join(", ")}\n${REASON_LABELS[judgment.reason]}\n\n${command}`,
    );
    // A real denial aborts its own signal; changed authorization is still cancellation.
    if (
      !sameAuthorization() ||
      outcome === "cancelled" ||
      (outcome !== "user-denied" && signal.aborted)
    )
      return cancelled();
    record(outcome);
    return confirmationResult(outcome);
  });

  pi.registerCommand("gate", {
    description: "Bash auto-approval and confirmation (/gate git|jev [on|off], log)",
    getArgumentCompletions(prefix: string) {
      const query = prefix.trimStart().toLowerCase();
      const options = query.includes(" ")
        ? ["git on", "git off", "jev on", "jev off"]
        : ["git", "jev", "log"];
      const items = options
        .filter((item) => item.startsWith(query))
        .map((item) => ({ value: item, label: item }));
      return items.length ? items : null;
    },
    handler: async (args, ctx) => {
      const [rule, value, ...extra] = args.trim().toLowerCase().split(/\s+/);
      if (!rule) {
        ctx.ui.notify(
          `Git approval: ${gitEnabled ? "ON" : "OFF"}; Jev auto-approval: ${jevEnabled ? "ON" : "OFF"}\n${USAGE}`,
          "info",
        );
        return;
      }
      if (rule === "log" && !value && !extra.length) {
        showLog(ctx);
        return;
      }
      if (
        !["git", "jev"].includes(rule) ||
        extra.length ||
        (value && value !== "on" && value !== "off")
      ) {
        ctx.ui.notify(USAGE, "error");
        return;
      }
      if (rule === "git") {
        if (value) gitEnabled = value === "on";
        ctx.ui.notify(`Git approval: ${gitEnabled ? "ON" : "OFF"}`, "info");
      } else {
        if (value) jevEnabled = value === "on";
        ctx.ui.notify(`Jev auto-approval: ${jevEnabled ? "ON" : "OFF"}`, "info");
      }
    },
  });
}
