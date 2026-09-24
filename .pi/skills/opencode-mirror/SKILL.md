---
name: opencode-mirror
description: Keep the pi websearch and webfetch extensions mirroring upstream OpenCode v2. Measure drift since each README pin, port changes across providers, selection, fetch, and conversion layers, record deviations in the ledger, verify with golden tests and print-mode runs, move the pin. Use when asked to check OpenCode upstream changes for websearch or webfetch, sync or port either mirror, change a search provider or fetch/conversion path, or triage review findings against either extension.
disable-model-invocation: true
---

# Mirroring opencode

The pi `websearch` and `webfetch` extensions each mirror one version of OpenCode's counterpart tool. Three words anchor this skill:

- **Upstream** is anomalyco/opencode, `v2` release line. Port only from `v2`; the `dev` line (v1.18.x) is the frozen architecture both mirrors replaced.
- **Pin** is the commit hash + date in each extension README's first paragraph. All drift is measured from it.
- **Ledger** is each README's "Differences from OpenCode v2" section: the single source of truth for every intentional divergence. A deviation absent from the ledger is a bug; a bug fixed where the mirror otherwise follows v2 is a new ledger entry.

## Sync run

1. Refresh the upstream cache:

   ```bash
   bash ~/.pi/agent/skills/librarian/checkout.sh anomalyco/opencode --path-only
   ```

2. Measure drift on the right line. Resolve file paths from the tree of the line you diff — locations moved between lines:

   ```bash
   git ls-tree -r --name-only origin/v2 | rg -i 'websearch|webfetch|html-markdown'
   git log --no-merges <pin>..origin/v2 -- <those paths>
   ```

   Unmerged `websearch-*` / `web-fetch` branches are direction signals; note them, leave them.

   Complete when every drifted commit is classified: **port** (implementation change), **availability** (only changes who gets the tool — skip), or **direction** (unmerged — note only).

3. Port each change onto the mirror's axes (sections below). Port discipline:

   - Whole-file ports stay verbatim, listed in `private_dot_pi/private_agent/oxfmt.config.ts` `ignorePatterns`, so drift diffs stay byte-comparable.
   - Upstream test assertions are the verification source: port them as golden checks before touching behavior.
   - A mechanism the mirror drops takes its copy with it — README/docs/description sentences must not claim unmirrored mechanisms ("user's selected search integration", "retained in managed storage").

   Complete when every classified **port** commit is mirrored or written into the ledger.

4. Verify, in this order: the AGENTS.md typecheck/lint for extensions; the mirror section's golden checks below; the print-mode E2E when selection or result consumption changed. A transport claim in a comment or fix (structuredContent, Retry-After, isError, budget caps) backs onto the MCP 2025-06-18 spec first — a SHOULD is not a MUST, classify before writing.

5. Move the pin (README hash + date) and clean up: a source deletion leaves the deployed copy orphaned — chezmoi applies additions, not removals; rm the target too. A sync without a moved pin leaves the next drift check reading stale.

## websearch mirror (reference)

| Axis | Upstream (v2) home | Mirror home |
| --- | --- | --- |
| Provider set: exa, parallel, firecrawl, tavily (tinyfish is a ledger exclusion) | `packages/core/src/plugin/websearch/*` | `providers/*` |
| Selection: forced / random + per-session affinity + 429 cooldown + failover | `packages/core/src/websearch.ts` | `selection.ts` |
| Tool schema (query only) + description | `packages/core/src/tool/plugin/websearch.ts` | `index.ts` |
| Result consumption: structured results → markdown | tool content formatting | `index.ts` formatResults |
| Error mapping: 429 / 401 / generic | tool `ToolFailure` | `index.ts` wrapWebsearchError over `HttpCallError` |
| Response shape tolerance | per-provider Effect schemas (strict) | `mcp-client.ts` extractText + per-provider runtime checks (looser, ledgered) |

Smoke checks: jiti-load a provider and execute with env manipulation (`env -u TAVILY_API_KEY`, `env -u PARALLEL_API_KEY`). Known outcomes: keyless Parallel returns ~10 results; keyless Tavily answers HTTP 503 — its exclusion from random routing (requiresApiKey) is a ledger entry, not a bug to fix. E2E asserts on the session jsonl: a `websearch.selection` custom entry exists, `details.provider` matches, result content is `## [title](url)` markdown; resume stickiness: rerun twice with `--session <file>`, provider stays fixed and the selection entry gains no duplicates.

## webfetch mirror (reference)

| Axis | Upstream (v2) home | Mirror home |
| --- | --- | --- |
| Markdown renderer | `packages/core/src/tool/html-markdown.ts` | `html-markdown.ts` (verbatim, oxfmt-exempt) |
| Request identity: OpenCode-User UA, bare `opencode` on Cloudflare 403 retry | `packages/core/src/tool/plugin/webfetch.ts` | `index.ts` |
| Mime whitelist + error narrowing (`Unable to fetch <url>`) | same | `index.ts` |
| Tool schema (timeout (0, 120] fail-fast) + description | same | `index.ts` |
| Text extraction | `tool/plugin/webfetch.ts` (in-module export) | `index.ts` (bottom, exported — like upstream) |
| Truncation + full-output temp file | central ToolOutput service | `index.ts` (pi brackets) |
| Images | v2 fails on images | pi-native `{type:"image"}` keep (ledgered) |

Golden checks: port assertions from `packages/core/test/tool-webfetch.test.ts` and `tool-html-markdown-budget.test.ts` (conversions, inline-code boundaries, byte-budget edge cases). Verbatim check: `diff <(git show origin/v2:.../html-markdown.ts) <mirror file>` is empty. E2E: fetch a known page in markdown and text formats, assert `details` = `{url, format, contentType}`.

Known shared caveat (ledgered, deliberately not fixed): the renderer silently caps conversion at ~5MB, so the "full output" file can hold a capped conversion — the overclaim matches upstream.

## Verification recipe (reference)

No-model-call smoke via jiti (from pi's own install, the `node_modules/jiti/lib/jiti.mjs` beside the `pi-coding-agent` package):

```js
import { createJiti } from "<pi install>/node_modules/jiti/lib/jiti.mjs";
const jiti = createJiti(import.meta.url);
const mod = await jiti.import("<repo>/private_dot_pi/private_agent/extensions/<name>/<file>.ts");
```

Print-mode E2E: `pi --print 'Call the <tool> tool once with …'`, then assert in the session jsonl under `~/.pi/agent/sessions/` (details fields, persistence entries, result shape).

## Findings triage (reference)

First question on any review finding or bug: does upstream v2 have it?

- **Inherited** — v2 shares it (429-only failover wedging a session on a dead keyless provider; budget-capped conversion presented as full output). Fix when behavior demands it; the fix is a ledger entry. Otherwise record it and keep parity.
- **Own** — artifact of mirror-local architecture (structured-only MCP responses dropped by text-first extraction). Just fix.

Where the mirror kept upstream's architecture, bugs inherit; where it diverged, it grows its own. Split every diff along that line before deciding what a finding means.
