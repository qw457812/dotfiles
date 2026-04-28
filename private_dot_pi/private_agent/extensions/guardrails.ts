import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

interface GuardrailsBlockedEvent {
  feature: "policies" | "permissionGate" | "pathAccess";
  toolName: string;
  input: Record<string, unknown>;
  reason: string;
  userDenied?: boolean;
}

export default function (pi: ExtensionAPI) {
  // Store ctx for use in event handler
  let currentCtx: ExtensionContext | undefined;

  pi.on("session_start", async (_event, ctx) => {
    currentCtx = ctx;
  });

  // https://github.com/aliou/pi-guardrails/blob/ba06d720196c68825274f652dadd1032260f64ad/src/utils/events.ts#L24
  pi.events.on("guardrails:blocked", (data: unknown) => {
    const { feature, userDenied } = data as GuardrailsBlockedEvent;
    if (userDenied && feature === "permissionGate") {
      currentCtx?.abort();
    }
  });
}
