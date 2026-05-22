import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ref: https://github.com/aliou/pi-guardrails/blob/v0.13.0/src/shared/events.ts
type GuardrailsBlockSource = "policy" | "permission" | "user" | "nonInteractive";

type Action =
  | { kind: "file"; path: string; origin?: string }
  | { kind: "command"; command: string; origin?: string };

interface GuardrailsActionBlockedPayload {
  source: "guardrails";
  feature: "policies" | "permissionGate" | "pathAccess";
  timestamp: string;
  action: Action;
  reason: string;
  block: { source: GuardrailsBlockSource; metadata?: unknown };
  context?: { toolName?: string; input?: Record<string, unknown> };
}

interface GuardrailsActionPromptedPayload {
  source: "guardrails";
  feature: "policies" | "permissionGate" | "pathAccess";
  timestamp: string;
  action: Action;
  reason: string;
  prompt: {
    /** What kind of prompt was shown */
    kind: "confirmation" | "permission";
    /** The feature-specific metadata about the risk */
    metadata?: unknown;
  };
  context?: { toolName?: string; input?: Record<string, unknown> };
}

export default function (pi: ExtensionAPI) {
  // Store ctx for use in event handler
  let currentCtx: ExtensionContext | undefined;

  pi.on("session_start", async (_event, ctx) => {
    currentCtx = ctx;
  });

  const offGuardrailsActionBlocked = pi.events.on("guardrails:action:blocked", (data: unknown) => {
    const { feature, block } = data as GuardrailsActionBlockedPayload;
    if (block.source === "user" && feature === "permissionGate") {
      currentCtx?.abort();
    }
  });

  const offGuardrailsActionPrompted = pi.events.on(
    "guardrails:action:prompted",
    (data: unknown) => {
      const { action, prompt, reason } = data as GuardrailsActionPromptedPayload;
      pi.events.emit("my:notification", {
        title: `pi-guardrails:action:prompted (${prompt.kind})`,
        body: `${action.kind === "command" ? action.command : action.path}\n${reason}`,
      });
    },
  );

  pi.on("session_shutdown", () => {
    currentCtx = undefined;
    offGuardrailsActionBlocked();
    offGuardrailsActionPrompted();
  });
}
