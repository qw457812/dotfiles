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
 * is categorically excluded from auto-approval. Full commands and the latest real user
 * message are sent to typesafe/jev-latest WITHOUT redaction; never tool output/history.
 * Missing authorization, oversized inputs and classification failures ask the user;
 * ask without UI blocks. Parser exceptions retain the existing warn-and-allow behavior.
 *
 * Coverage is unchanged: dynamic names, aliases, functions, wrappers (env, command,
 * xargs, shell -c), eval strings, expansions and filesystem state are not resolved.
 * Temporary-directory deletion exemptions remain. Only bash tool_call is handled,
 * including nested calls through codemode, not user_bash or other tools.
 * safe-guard.ts owns write/edit protection; dirty-repo-guard.ts owns dirty-repo reminders.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withBashTree } from "../../lib/bash-parser.ts";
import { withConfirmationQueue } from "../../lib/confirmation-queue.ts";
import { approvalRules, RULE_LABELS } from "./policy.ts";
import {
  GATE_MODEL,
  QUESTION_VERSION,
  REASON_LABELS,
  judgeCommand,
  type GateJudgment,
} from "./jev.ts";
import { latestUserIntent, inputFingerprint, userText, type GateInputSource } from "./intent.ts";
import { GATE_ENTRY, showLog, type GateRecord, type Outcome } from "./log.ts";

export { GATE_ENTRY } from "./log.ts";
const USAGE = "Usage: /gate git [on|off] | jev [on|off] | log";

export default function (pi: ExtensionAPI) {
  let gitEnabled = true;
  let jevEnabled = true;
  let lifecycle = new AbortController();
  let pendingInputs: {
    fingerprint: string;
    source: GateInputSource;
    queued: boolean;
    expandable: boolean;
  }[] = [];

  pi.on("input", (event) => {
    pendingInputs.push({
      fingerprint: inputFingerprint(event.text),
      source: event.source,
      queued: event.streamingBehavior !== undefined,
      expandable: event.text.startsWith("/"),
    });
    pendingInputs = pendingInputs.slice(-128);
  });
  pi.on("before_agent_start", (event) => {
    const fingerprint = inputFingerprint(event.prompt);
    const candidate = pendingInputs[0];
    // Pi emits input before slash-template/skill expansion, then this event with
    // the expanded prompt. Bridge only a single, non-queued slash input.
    if (pendingInputs.length === 1 && !candidate.queued && candidate.expandable) {
      pendingInputs = [{ ...candidate, fingerprint, expandable: false }];
      return;
    }
    if (pendingInputs.some((input) => !input.queued && input.fingerprint !== fingerprint)) {
      // Do not guess between candidates, or leak stale handled/transformed inputs
      // into a later run. An exact-match queued input cannot resolve this ambiguity.
      pendingInputs = pendingInputs.filter(
        (input) => input.queued || input.fingerprint === fingerprint,
      );
      pendingInputs.push({ fingerprint, source: "unknown", queued: false, expandable: false });
    }
  });
  pi.on("message_end", (event) => {
    if (event.message.role !== "user") return;
    const fingerprint = inputFingerprint(userText(event.message.content));
    const matches = pendingInputs.filter((input) => input.fingerprint === fingerprint);
    pendingInputs = pendingInputs.filter((input) => input.fingerprint !== fingerprint);
    const sources = new Set(matches.map((input) => input.source));
    const source: GateInputSource = sources.size === 1 ? matches[0].source : "unknown";
    // Pi otherwise drops InputEvent.source when persisting a regular user message.
    return { message: { ...event.message, permissionGateSource: source } };
  });

  const invalidate = () => {
    pendingInputs = [];
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
    const current = () =>
      !signal.aborted &&
      ctx.sessionManager.getSessionId() === sessionId &&
      latestUserIntent(ctx.sessionManager.getBranch())?.id === user?.id;
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
      judgment = await judgeCommand(
        ctx.modelRegistry,
        command,
        user?.text ?? "",
        ctx.cwd,
        rules,
        signal,
      );
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
      return { block: true, reason: "Permission Gate: operation cancelled" };
    };
    if (!current() || judgment.action === "cancelled") return cancelled();
    if (judgment.action === "allow") {
      record("auto-approved");
      return;
    }
    if (!ctx.hasUI) {
      record("no-ui");
      return { block: true, reason: "Command requires user confirmation" };
    }

    // Classification is parallel; dialogs share a queue with the path and SQL guards.
    return withConfirmationQueue(ctx.ui, async () => {
      try {
        if (!current()) return cancelled();
        pi.events.emit("my:notification", { title: "Pi Danger Approval", body: command });
        const description = `Rules: ${rules.map((rule) => RULE_LABELS[rule]).join(", ")}\n${REASON_LABELS[judgment.reason]}\n\n${command}`;
        const ok = await ctx.ui.confirm("🔐 Allow this command?", description, { signal });
        if (!current()) return cancelled();
        if (!ok) {
          record("user-denied");
          ctx.abort();
          return { block: true, reason: "Blocked by user" };
        }
        record("user-approved");
      } catch {
        if (!current()) return cancelled();
        record("confirmation-failed");
        return { block: true, reason: "User confirmation failed" };
      }
    });
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
