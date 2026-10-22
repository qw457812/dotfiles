import type {
  ExtensionAPI,
  ExtensionContext,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";

export type ConfirmationOutcome =
  | "user-approved"
  | "user-denied"
  | "no-ui"
  | "cancelled"
  | "confirmation-failed";

/** Use Pi's dialog stack and return an outcome, without deciding the caller's policy. */
export async function confirm(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  title: string,
  message: string,
): Promise<ConfirmationOutcome> {
  const signal = ctx.signal;
  if (signal?.aborted) return "cancelled";
  if (!ctx.hasUI) return "no-ui";

  try {
    pi.events.emit("my:notification", { title, body: message });
    const approved = signal
      ? await ctx.ui.confirm(title, message, { signal })
      : await ctx.ui.confirm(title, message);
    if (signal?.aborted) return "cancelled";
    if (!approved) {
      ctx.abort(); // Cancel sibling confirmations sharing this operation's signal.
      return "user-denied";
    }
    return "user-approved";
  } catch {
    return signal?.aborted ? "cancelled" : "confirmation-failed";
  }
}

/** Every guard uses the same blocking reasons. */
export function confirmationResult(outcome: ConfirmationOutcome): ToolCallEventResult | undefined {
  if (outcome === "user-approved") return;
  const reasons = {
    "user-denied": "Blocked by user",
    "no-ui": "Operation requires user confirmation",
    cancelled: "Permission Gate: operation cancelled",
    "confirmation-failed": "User confirmation failed",
  };
  return { block: true, reason: reasons[outcome] };
}
