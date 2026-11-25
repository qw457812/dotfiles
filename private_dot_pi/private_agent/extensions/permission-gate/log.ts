import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { ConfirmationOutcome } from "./confirmation.ts";
import { GATE_MODEL, REASON_LABELS, type GateJudgment } from "./jev.ts";

export const GATE_ENTRY = "permission-gate-decision";
export const GIT_RULE_LABEL = "Git operation";

export type GateRule = "git" | "sql";
const RULE_LABELS: Partial<Record<string, string>> = { git: GIT_RULE_LABEL, sql: "SQL" };

export type Outcome = "auto-approved" | ConfirmationOutcome;
export interface GateRecord {
  version: 1;
  questionVersion: number;
  timestamp: string;
  model: string;
  rules: string[]; // Older records can contain several rules, including retired names.
  judgment: GateJudgment;
  durationMs: number;
  outcome: Outcome;
}

export function recordDecision(
  pi: ExtensionAPI,
  decision: Omit<GateRecord, "version" | "timestamp" | "model" | "rules"> & { rule: GateRule },
) {
  pi.appendEntry<GateRecord>(GATE_ENTRY, {
    version: 1,
    questionVersion: decision.questionVersion,
    timestamp: new Date().toISOString(),
    model: `${GATE_MODEL.provider}/${GATE_MODEL.id}`,
    rules: [decision.rule],
    judgment: decision.judgment,
    durationMs: decision.durationMs,
    outcome: decision.outcome,
  });
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
      ? `\n  ${Object.entries(p)
          .map(([key, value]) => `${key}=${value.toFixed(3)}`)
          .join(" ")}`
      : "";
    return `${record.timestamp} · ${record.rules.map((rule) => RULE_LABELS[rule] ?? rule).join(", ")} · ${record.judgment.action} / ${record.outcome}\n  ${REASON_LABELS[record.judgment.reason]} · ${record.model} · ${record.durationMs}ms · questions v${record.questionVersion}${scores}`;
  });
  ctx.ui.notify(lines.length ? lines.join("\n\n") : "No Jev decisions on this branch.", "info");
}
