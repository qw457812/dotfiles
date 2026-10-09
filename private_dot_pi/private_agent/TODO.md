## Sandbox and Permission Gate

- [https://github.com/earendil-works/pi/blob/3e5ad67e0f325d4888f82f9b82966218eb4407f5/packages/coding-agent/examples/extensions/permission-gate.ts](https://github.com/earendil-works/pi/blob/3e5ad67e0f325d4888f82f9b82966218eb4407f5/packages/coding-agent/examples/extensions/permission-gate.ts)

### LLM or Jev Judge

- [https://github.com/olimorris/codecompanion.nvim/commit/b64ce79484ad407d127c245cc5a35eba520201d6](https://github.com/olimorris/codecompanion.nvim/commit/b64ce79484ad407d127c245cc5a35eba520201d6)
- [https://github.com/anthropics/skills/commit/34040c9c568585f6929bedeaad110ad08f079624](https://github.com/anthropics/skills/commit/34040c9c568585f6929bedeaad110ad08f079624)

GitHub star counts checked 2026-10-09; counts are snapshots.

- [Jomatsu / pi-jev-auto-mode](https://github.com/jomatsu/pi-jev-auto-mode) — Pi auto mode, local policies, Jev engine and calibration fixtures. ⭐ 31
- [kurihada / pi-jev-permit](https://github.com/kurihada/pi-jev-permit) — Pi permission gate for bash/write/edit with deterministic fast paths and separate risk/authorization judgments. ⭐ 1
- [riposta / pi-jev](https://github.com/riposta/pi-jev) — Modular Pi Jev layer with gate, shield, router and shadow-first calibration. ⭐ 1
- [leepokai / jev-guard](https://github.com/leepokai/jev-guard) — Multi-agent hooks, session context and prompt-injection scanning. ⭐ 63
- [MoonTory / claude-jev-guard](https://github.com/MoonTory/claude-jev-guard) — Claude Code hook and three-way risk policy. ⭐ 0
- [madisonrickert / jev-permission-gate](https://github.com/madisonrickert/jev-permission-gate) — Claude Code auto-mode gate with a shell-aware prefilter and held-out evaluations. ⭐ 28
- [omkarghugarkar007 / actiongate-jev](https://github.com/omkarghugarkar007/actiongate-jev) — Deterministic policy plus exact-action, single-use authorization grants. ⭐ 2
- [alexj11324 / open-jev-approvals](https://github.com/alexj11324/open-jev-approvals) — Binary approval gate with scoped authorization and local policy; Jev/audit failures fail open. ⭐ 3
- [vercel-labs / github-tools](https://github.com/vercel-labs/github-tools) — Decision + Approval example for GitHub API actions \(not a local shell permission gate\). ⭐ 131
- [Command Safety](https://www.jevtypesafeai.com/tools/command-safety) — Independent third-party demo using the TypeSafe API, not an official TypeSafe project.

### Additional Permission-Gate Projects

- [jesset / pi-verdict](https://github.com/jesset/pi-verdict) — Pi three-state permission gate with a deterministic deny floor, fail-closed classifier/Jev decisions, and self-protection. ⭐ 12
- [DevMortimer / pi-warden](https://github.com/DevMortimer/pi-warden) — Broad Pi guardrails with an action gate and maintainer-reported field usage; default `steer` mode is not equivalent to mandatory human approval. ⭐ 164
- [BubbatheVTOG / pi-jev-tool-guard](https://github.com/BubbatheVTOG/pi-jev-tool-guard) — Context-aware Pi gate for bash/write/edit; evaluator failure defaults to fail-open but is configurable. ⭐ 0
- [JasonHZS / pi-jev-command-guard](https://github.com/JasonHZS/pi-jev-command-guard) — Pi Bash/PowerShell approval gate with local danger rules and Jev confidence thresholds; supports persistent command-prefix grants. ⭐ 0
- [weiping / jev-pi](https://github.com/weiping/jev-pi) — Pi package combining a Jev permission gate with output, context, and agent-routing modules. ⭐ 1
- [RiskAverseTech / toolgate](https://github.com/RiskAverseTech/toolgate) — Claude Code hook and MCP proxy with static policy, typed Jev risk axes, a write-then-execute ledger, and published targeted evaluations. ⭐ 19
- [ursuciprian / reflex](https://github.com/ursuciprian/reflex) — Cross-agent pre-execution risk gate with prompt-injection controls and optional Jev. ⭐ 3
- [klukacin / JEV\_Claude\_plugin](https://github.com/klukacin/JEV_Claude_plugin) — Useful negative field report: the author disabled its Jev shell gate after reporting \~12,000 calls, 126 minutes of added latency, and no demonstrated prevented damage. ⭐ 0

### Adjacent Jev Projects \(Not Shell Permission Gates\)

- [hcl-z / pi-jev-gate](https://github.com/hcl-z/pi-jev-gate) — Checks file changes against project `constraints.md`; not a pre-execution shell permission gate. ⭐ 1
- [TheoOliveira / pi-jev](https://github.com/TheoOliveira/pi-jev) — Pi typed-decision and tool-routing package with a post-run Jev gate CLI; not a pre-execution permission gate. ⭐ 63

## Permission-Gate Jev Improvements (source-referenced)

Survey of the REFERENCE.md harnesses' Jev integrations, ranked by usefulness to `extensions/permission-gate`.

### Priority 1 — Latency: hedged requests / session affinity

- [1jehuang / jcode — `crates/jcode-base/src/jev.rs`](https://github.com/1jehuang/jcode/blob/main/crates/jcode-base/src/jev.rs) — Measured TypeSafe latency is bimodal and sticky per connection: ~150ms or 2–12s. Hedges duplicate requests after 300/700/1500ms and takes the first answer; judgments are side-effect-free and input tokens are cheap ($42/Btok, output free), so hedging is nearly free. Our `CLASSIFY_TIMEOUT = 5_000` lands in the slow bucket → timeout → unnecessary `ask`.
- [anomalyco / opencode — `packages/console/app/src/routes/zen/util/provider/systemone.ts`](https://github.com/anomalyco/opencode/blob/main/packages/console/app/src/routes/zen/util/provider/systemone.ts) — Sends `x-session-affinity` per request to pin sticky connections; cheaper than hedging if pi's `ProviderRequestOptions.headers` passes through.
- Goal: fewer `timeout`/`unavailable` asks without raising the 5s ceiling.

### Priority 2 — Request hygiene: state slimming, model pinning, injectable backend

- [vercel-labs / fx — `src/builtins/gateway/typesafe_permission_reviewer.zig`](https://github.com/vercel-labs/fx/blob/main/src/builtins/gateway/typesafe_permission_reviewer.zig) — Minimal state: only `review_policy` + the pending action. Context rot (Jev docs: accuracy falls with irrelevant state) says our unused `cwd`/`matched_rules` fields should be dropped or referenced in instructions.
- [vercel-labs / fx — e2e stub](https://github.com/vercel-labs/fx/blob/main/tests/e2e/review-model-override.test.ts) — Local stub server returns fixed Jev responses; make `judgeCommand` accept an injectable classify function for tests.
- [can1357 / oh-my-pi — `packages/ai/src/judgment/typesafe.ts`](https://github.com/can1357/oh-my-pi/blob/main/packages/ai/src/judgment/typesafe.ts) — Bounded retry with `retry-after` awareness on 429/5xx; model overridable via `TYPESAFE_DEFAULT_MODEL` env. Add a `PERMISSION_GATE_MODEL`-style env and pin `jev-1.13.0` instead of the `jev-latest` alias (alias moves under hand-tuned 0.9/0.1 thresholds; pi's ClassifierResult doesn't surface the responding version).
- [can1357 / oh-my-pi — `packages/ai/src/judgment/`](https://github.com/can1357/oh-my-pi/tree/main/packages/ai/src/judgment) — Judge abstraction split from backend (native TypeSafe, OpenRouter decisions route, TextJudge chat fallback). Also `Encoding.Jev` offline token counting with longest-prefix truncation vs our char limits.

### Priority 3 — Privacy: redact credentials in `user_intent`

- [NousResearch / hermes-agent — `jev-approvals` plugin](https://github.com/NousResearch/hermes-agent/blob/main/plugin-catalog/jev-approvals.yaml) — Redacts command credentials before sending, validates typed answer shapes, bounded structured audit log, fail-closed. Our extension sends full unredacted `user_intent`; user messages containing tokens/passwords leave the machine verbatim.

### Priority 4 — Threshold calibration: replay logged probabilities

- [NousResearch / hermes-agent — `evals/compaction/results/SCORECARD-2026-09-19-jev.md`](https://github.com/NousResearch/hermes-agent/blob/main/evals/compaction/results/SCORECARD-2026-09-19-jev.md) — Runs Jev over a sample set and keeps a scored card. Our `log.ts` already records per-decision probabilities; replay them to tune 0.9/0.1 empirically, including tighter thresholds for CJK (Han-script) intents, instead of hand-picking.
- Background: [vercel-labs / fx gates nothing on probabilities](https://github.com/vercel-labs/fx/blob/main/src/builtins/gateway/typesafe_permission_reviewer.zig) (records only); TypeSafe docs' confidence-routing pattern supports hard thresholds — calibration is the missing piece either way.

### Already covered / not applicable

- Double-negative `unexpected_harm` question → rephrase positively (`effects_covered`) + bump `QUESTION_VERSION` (TypeSafe Noul docs: phrase so high value = yes; jaggedness: indirection/double negatives cost accuracy).
- Redundant abort/timeout plumbing in `judgeCommand` (pi's `classify()` never rejects and applies `timeoutMs` internally) — single-source the timer.
- First `unavailable` → one-shot UI notice (like the parser-failure path); log `ClassifierResult.usage` in `GateRecord`.
- Not applicable: dirge `classify-many` fan-out (single-command case), fx's injection/malice criteria (different threat model), hermes per-tool-call compaction questions.

## Multi Codex Account

[https://github.com/Sarrius/pi-multi-account](https://github.com/Sarrius/pi-multi-account)

[https://github.com/monotykamary/pi-multiprovider](https://github.com/monotykamary/pi-multiprovider)

## web-search

- `npm:@earendil-works/pi-radius-web-search`
