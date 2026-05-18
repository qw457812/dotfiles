import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ref: https://github.com/aliou/pi-guardrails/blob/v0.12.1/src/shared/events.ts
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

interface GuardrailsRiskDetectedPayload {
  source: "guardrails";
  feature: "policies" | "permissionGate" | "pathAccess";
  timestamp: string;
  risk: {
    kind: "dangerous";
    action: Action;
    key: string;
    reason: string;
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

  const offGuardrailsRiskDetected = pi.events.on("guardrails:risk:detected", (data: unknown) => {
    const { risk } = data as GuardrailsRiskDetectedPayload;
    pi.events.emit("my:notification", {
      title: "pi-guardrails:risk:detected",
      body: `${risk.action.kind === "command" ? risk.action.command : risk.action.path}\n${risk.reason}\n${risk.key}`,
    });
  });

  pi.on("session_shutdown", () => {
    currentCtx = undefined;
    offGuardrailsActionBlocked();
    offGuardrailsRiskDetected();
  });
}
