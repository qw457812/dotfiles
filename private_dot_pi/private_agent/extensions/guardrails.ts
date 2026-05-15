import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

interface GuardrailsBlockedEvent {
  feature: "policies" | "permissionGate" | "pathAccess";
  toolName: string;
  input: Record<string, unknown>;
  reason: string;
  userDenied?: boolean;
}

// TODO: switch to this when upstream @aliou/pi-guardrails 0.12.0+ ships
/*
type GuardrailsBlockSource = "policy" | "permission" | "user" | "nonInteractive";

interface GuardrailsActionBlockedPayload {
  source: "guardrails";
  feature: "policies" | "permissionGate" | "pathAccess";
  timestamp: string;
  action: { kind: "file" | "command"; path?: string; command?: string; origin?: string };
  reason: string;
  block: { source: GuardrailsBlockSource; metadata?: unknown };
  context?: { toolName?: string; input?: Record<string, unknown> };
}
*/

export default function (pi: ExtensionAPI) {
  // Store ctx for use in event handler
  let currentCtx: ExtensionContext | undefined;

  pi.on("session_start", async (_event, ctx) => {
    currentCtx = ctx;
  });

  // https://github.com/aliou/pi-guardrails/blob/ba06d720196c68825274f652dadd1032260f64ad/src/utils/events.ts#L24
  const offGuardrailsBlocked = pi.events.on("guardrails:blocked", (data: unknown) => {
    const { feature, userDenied } = data as GuardrailsBlockedEvent;
    if (userDenied && feature === "permissionGate") {
      currentCtx?.abort();
    }
  });

  // TODO: switch to this when upstream @aliou/pi-guardrails 0.12.0+ ships
  // ref: https://github.com/aliou/pi-guardrails/blob/a57fe81595d8b787bd7e9ad0ef054a101392f6c8/src/shared/events.ts
  /*
  const offGuardrailsActionBlocked = pi.events.on("guardrails:action:blocked", (data: unknown) => {
    const { feature, block } = data as GuardrailsActionBlockedPayload;
    if (block.source === "user" && feature === "permissionGate") {
      currentCtx?.abort();
    }
  });
  */

  pi.on("session_shutdown", async () => {
    currentCtx = undefined;
    offGuardrailsBlocked();
    // offGuardrailsActionBlocked(); // TODO: enable when upstream 0.12.0+ ships
  });
}
