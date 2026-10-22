import type {
  ExtensionAPI,
  ExtensionContext,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { confirm, confirmationResult } from "./confirmation.ts";
import type { GateJudgment } from "./jev.ts";
import { recordDecision, type GateRecord, type Outcome } from "./log.ts";

interface ApprovalOptions {
  signal: AbortSignal;
  /** Session/authorization validity, excluding the signal a genuine denial aborts. */
  isValid: () => boolean;
  /** Session/lifecycle validity only: cancelled authorization can still be logged. */
  canRecord: () => boolean;
  /** Omit when disabled or input is missing; neither case writes a decision entry. */
  classify?: () => Promise<GateJudgment>;
  questionVersion: number;
  rules: GateRecord["rules"];
  title: string;
  message: (judgment: GateJudgment) => string;
}

/** Classify and confirm concurrently, with shared cancellation and validity checks. */
export async function requestApproval(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  options: ApprovalOptions,
): Promise<ToolCallEventResult | undefined> {
  const { signal, isValid, canRecord, classify } = options;
  const current = () => !signal.aborted && isValid();
  const started = Date.now();
  const judgment: GateJudgment = classify
    ? await classify()
    : { action: "ask", reason: "disabled" };
  const durationMs = Date.now() - started;
  const record = (outcome: Outcome, decision = judgment) => {
    // Never append an old operation's entry to a replacement session/branch.
    if (!classify || !canRecord()) return;
    recordDecision(pi, {
      questionVersion: options.questionVersion,
      rules: options.rules,
      judgment: decision,
      durationMs,
      outcome,
    });
  };
  const cancelled = () => {
    record("cancelled", { action: "cancelled", reason: "cancelled" });
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
    options.title,
    options.message(judgment),
  );
  // Denial aborts its own signal; changed session/authorization is still cancellation.
  if (!isValid() || outcome === "cancelled" || (outcome !== "user-denied" && signal.aborted))
    return cancelled();
  record(outcome);
  return confirmationResult(outcome);
}
