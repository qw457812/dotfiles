import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { withBashTree } from "../../lib/bash-parser.ts";
import { requestApproval } from "./approval.ts";
import { approvalRules, RULE_LABELS } from "./bash-rules.ts";
import { QUESTION_VERSION, REASON_LABELS, judgeCommand } from "./jev.ts";
import { latestUserIntent } from "./intent.ts";

export default function registerBashChecks(
  pi: ExtensionAPI,
  isGitEnabled: () => boolean,
  isJevEnabled: () => boolean,
  getLifetime: () => AbortSignal,
  isEnabled: () => boolean = () => true,
) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isEnabled()) return;
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

    const lifetime = getLifetime();
    const signal = ctx.signal ? AbortSignal.any([lifetime, ctx.signal]) : lifetime;
    const sessionId = ctx.sessionManager.getSessionId();
    const user = latestUserIntent(ctx.sessionManager.getBranch());
    const sameSession = () => !lifetime.aborted && ctx.sessionManager.getSessionId() === sessionId;
    const sameAuthorization = () =>
      sameSession() && latestUserIntent(ctx.sessionManager.getBranch())?.id === user?.id;
    const rules = await withBashTree(command, (root) => approvalRules(root, isGitEnabled())).catch(
      () => {
        if (ctx.hasUI)
          ctx.ui.notify("Permission Gate: command checks skipped (parser failure)", "warning");
        return [];
      },
    );
    if (!rules.length) return;

    return requestApproval(pi, ctx, {
      signal,
      isValid: sameAuthorization,
      canRecord: sameSession,
      classify: isJevEnabled()
        ? () =>
            judgeCommand(
              ctx.modelRegistry,
              command,
              user?.text ?? "",
              ctx.cwd,
              signal,
              rules.length === 1 && rules[0] === "git",
              rules.every((rule) => rule === "git" || rule === "rm"),
            )
        : undefined,
      questionVersion: QUESTION_VERSION,
      rules,
      title: "🔐 Allow this command?",
      message: (judgment) =>
        `Rules: ${rules.map((rule) => RULE_LABELS[rule]).join(", ")}\n${REASON_LABELS[judgment.reason]}\n\n${command}`,
    });
  });
}
