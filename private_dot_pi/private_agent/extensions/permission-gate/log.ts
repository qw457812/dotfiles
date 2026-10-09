import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { REASON_LABELS, type GateJudgment } from "./jev.ts";
import { RULE_LABELS, type GateRule } from "./policy.ts";

export const GATE_ENTRY = "permission-gate-decision";

export type Outcome =
  | "auto-approved"
  | "user-approved"
  | "user-denied"
  | "no-ui"
  | "cancelled"
  | "confirmation-failed";
export interface GateRecord {
  version: 1;
  questionVersion: number;
  timestamp: string;
  model: string;
  rules: GateRule[];
  judgment: GateJudgment;
  durationMs: number;
  outcome: Outcome;
}

export function showLog(ctx: ExtensionContext) {
  const records = ctx.sessionManager
    .getBranch()
    .filter((entry) => entry.type === "custom" && entry.customType === GATE_ENTRY)
    .map((entry) => (entry.type === "custom" ? (entry.data as GateRecord) : undefined))
    .filter((record): record is GateRecord => record?.version === 1)
    .slice(-20);
  const lines = records.map((record) => {
    const p = record.judgment.probabilities;
    const scores = p
      ? `\n  intent=${p.intent_covered.toFixed(3)} scope=${p.scope_covered.toFixed(3)} unexpected_harm=${p.unexpected_harm.toFixed(3)}`
      : "";
    return `${record.timestamp} · ${record.rules.map((rule) => RULE_LABELS[rule]).join(", ")} · ${record.judgment.action} / ${record.outcome}\n  ${REASON_LABELS[record.judgment.reason]} · ${record.model} · ${record.durationMs}ms · questions v${record.questionVersion}${scores}`;
  });
  ctx.ui.notify(lines.length ? lines.join("\n\n") : "No Jev decisions on this branch.", "info");
}
