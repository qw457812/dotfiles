---
name: websearch-mirror
description: Keep the pi websearch extension mirroring upstream OpenCode v2. Measure drift since the pinned commit, port provider / selection / result-consumption changes, record deviations in the README ledger, verify with provider smoke tests, move the pin. Use when asked to check upstream OpenCode websearch changes, sync or port the mirror, add or change a search provider, or triage review findings on the extension.
disable-model-invocation: true
---

# Mirroring websearch

The pi `websearch` extension mirrors one version of OpenCode's websearch. Three words anchor this skill:

- **Upstream** is anomalyco/opencode, `v2` release line. Port only from `v2`; the `dev` line (v1.18.x) is the frozen architecture the mirror replaced.
- **Pin** is the commit hash + date in the extension README's first paragraph. All drift is measured from it.
- **Ledger** is the README's "Differences from OpenCode v2" section: the single source of truth for every intentional divergence. A deviation absent from the ledger is a bug; a bug fixed where the mirror otherwise follows v2 is a new ledger entry.

## Sync run

1. Refresh the upstream cache:

   ```bash
   bash ~/.pi/agent/skills/librarian/checkout.sh anomalyco/opencode --path-only
   ```

2. Measure drift on the right line. Resolve file paths from the tree of the line you diff — locations moved between lines:

   ```bash
   git ls-tree -r --name-only origin/v2 | rg -i websearch
   git log --no-merges <pin>..origin/v2 -- <those paths>
   ```

   Unmerged `websearch-*` branches are direction signals; note them, leave them.

   Complete when every drifted commit is classified: **port** (implementation change), **availability** (only changes who gets the tool — skip), or **direction** (unmerged — note only).

3. Port each change onto the axes table below. For each axis changed: align behavior exactly, or draft the ledger entry in the same change.

   Complete when every classified **port** commit is mirrored or written into the ledger.

4. Verify, in this order: the AGENTS.md typecheck/lint for extensions; the provider smoke recipes; the print-mode E2E when selection or result consumption changed. A transport claim in a comment or fix (structuredContent, Retry-After, isError) backs onto the MCP 2025-06-18 spec first — a SHOULD is not a MUST, classify before writing.

5. Move the pin: README hash + date. A sync without a moved pin leaves the next drift check reading stale.

## Axes (reference)

| Axis | Upstream (v2) home | Mirror home |
| --- | --- | --- |
| Provider set: exa, parallel, firecrawl, tavily (tinyfish is a ledger exclusion) | `packages/core/src/plugin/websearch/*` | `providers/*` |
| Selection: forced / random + per-session affinity + 429 cooldown + failover | `packages/core/src/websearch.ts` | `selection.ts` |
| Tool schema (query only) + description | `packages/core/src/tool/plugin/websearch.ts` | `index.ts` |
| Result consumption: structured results → markdown | tool content formatting | `index.ts` formatResults |
| Error mapping: 429 / 401 / generic | tool `ToolFailure` | `index.ts` wrapWebsearchError over `HttpCallError` |
| Response shape tolerance | per-provider Effect schemas (strict) | `mcp-client.ts` extractText + per-provider runtime checks (looser, ledgered) |

## Verification recipes (reference)

Provider smoke test — no model call, no session; jiti-load a provider and execute. Use jiti from pi's own install (the `node_modules/jiti/lib/jiti.mjs` beside the `pi-coding-agent` package):

```js
import { createJiti } from "<pi install>/node_modules/jiti/lib/jiti.mjs";
const jiti = createJiti(import.meta.url);
const mod = await jiti.import("<repo>/private_dot_pi/private_agent/extensions/websearch/providers/<id>.ts");
```

Drive per case with env manipulation: `env -u TAVILY_API_KEY node …`. Known expected outcomes: keyless Parallel returns ~10 results; keyless Tavily answers HTTP 503 — that exclusion from random routing is a ledger entry, not a bug to fix.

Print-mode E2E — `pi --print 'Call the websearch tool once with query "…"'`, then assert on the session jsonl (under `~/.pi/agent/sessions/`): a `websearch.selection` custom entry exists, `details.provider` matches the TUI's provider, result content is `## [title](url)` markdown. For resume stickiness: rerun twice with `--session <file>`, provider stays fixed and the selection entry gains no duplicates.

## Findings triage (reference)

First question on any review finding or bug: does upstream v2 have it?

- **Inherited** — v2 shares it (429-only failover wedging a session on a dead keyless provider is the canonical example). Fix when behavior demands it; the fix is a ledger entry.
- **Own** — artifact of mirror-local architecture (structured-only MCP responses dropped by text-first extraction is the canonical example). Just fix.

Where the mirror kept upstream's architecture, bugs inherit; where it diverged, it grows its own. Split every diff along that line before deciding what a finding means.
