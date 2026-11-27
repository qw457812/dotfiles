---
name: opencode-mirror
description: Sync Pi’s webfetch and websearch mirrors with OpenCode, or review a finding for upstream parity.
disable-model-invocation: true
---

# OpenCode mirrors

**Upstream** is `anomalyco/opencode` on `origin/dev`; `v2` is a historical branch. The **pin** is the hash and date in each mirror README’s first paragraph. The **ledger** is its “Differences from Upstream” section. Read the relevant README for the current contract, intentional differences, and golden test command: [webfetch](../../../private_dot_pi/private_agent/extensions/webfetch/README.md) · [websearch](../../../private_dot_pi/private_agent/extensions/websearch/README.md).

## Sync

1. **Pin the comparison.** Refresh the cache with `bash ~/.pi/agent/skills/librarian/checkout.sh anomalyco/opencode --path-only`. Record the exact `origin/dev` hash and commit date; use that hash throughout the run. Use each README’s own pin as the base.
2. **Account for drift.** Use `git ls-tree -r --name-only` at both endpoints to locate the tool, helpers, and tests, then inspect `git log --no-merges <pin>..<target> -- <paths>` and the net diff. Start with `webfetch`, `websearch`, and `html-markdown`; trace shared dependencies when behavior moves out of those paths. Classify every relevant change: **port** for behavior, **availability** for exposure or integration plumbing the mirror does not use, **out of scope** for unrelated internals or docs. Unmerged branches are **direction** only. A drift-only review stops after reporting this classification.
3. **Port or ledger.** For each behavior change, port an upstream golden assertion or add a regression check if upstream has none. Add the check before editing behavior. Record deliberate omissions in the ledger. Keep whole-file ports byte-identical to the target and formatting-exempt. When dropping an upstream mechanism, update descriptions and docs that imply it still exists. For transport changes, check the applicable MCP specification version and distinguish protocol requirements from observed server behavior.
4. **Verify.** Run the extension checks in `AGENTS.md`, then the affected README’s golden tests. Check whole-file ports against the target hash, not `origin/v2`. If provider selection, result consumption, or output shape changes, run the applicable print-mode checks below. Report any check not run and why.
5. **Advance the pin.** Once all relevant changes are accounted for and verification passes, update the README hash/date and summarize the classification in Drift Notes. If the sync removes a managed source file, confirm that chezmoi also removed the deployed copy; remove a stale target if needed.

## Print-mode checks

Prefer deterministic fixtures for the model and remote responses. For direct calls, inspect the result sent to the model or its session entry. For codemode, assert on the value **inside the script** and emit a small success marker; the session records nested call status, not the nested return value.

- **Result consumption or output schema:** check direct `content` and the actual `tools.*()` return separately. Use a large fixture to prove that preview truncation and spill notices affect `content` but do not trim the script value. Keep transport, conversion, and codemode’s final output budgets distinct from preview truncation. Use the README’s Output section as the contract.
- **Provider selection or persistence:** check the selected provider, `details.provider`, and the `websearch.selection` entry during random selection. Resume the same session twice and check that the provider remains stable without duplicate selection entries.

## Review findings

Check the behavior at the mirror’s pin first, then at the current upstream target if checking drift. **Inherited:** keep parity or ledger a deliberate fix. **Mirror-local:** fix the Pi implementation and add a regression check. A documented difference is intentional unless the review explicitly changes that decision.
