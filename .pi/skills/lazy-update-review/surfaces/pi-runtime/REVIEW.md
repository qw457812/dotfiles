# Pi runtime: trace changed contracts to loaded consumers

Use the [frozen Pi ranges](../prompt-editor/REVIEW.md#1-freeze-the-ranges). Check every distinct checkout and published range; only the published range describes the installed CLI.

## 1. Resolve the consumers

Search for changed identifiers in `private_dot_pi/private_agent`, `symlinks/pi/agent` and project `.pi/` (including `settings.json` and `mcp.json`). Inspect model definitions and separately pinned development manifests as well as extension source. Project MCP exposure can change the tool loadout even if the global server list is empty.

Resolve each implicated package or path-valued extension to the code Pi actually loads. Search explicit installed entry/source paths with `rg --no-ignore` for third-party consumers under `node_modules`. For paths loaded directly from the lazy checkout, diff those paths at the exact revisions in the source cache and check their host imports even if the path itself is unchanged.

**Done when:** every changed contract has a list of local and installed consumers (or a recorded absence), and their runtime/development package ownership is clear.

## 2. Check implicated contracts

| If the diff changes… | Check… |
| --- | --- |
| Providers and models | Config types and root exports, cache unions, chat/image/classifier discrimination, provider events, auth and default model selection. |
| Tool/extension contexts or schemas | Nested calls, cancellation and tool-name/input routing; compare loader aliases with direct SDK imports. A runtime shim can hide standalone type errors. Compare schema shape, coercion and refinements, not just imports. |
| Command identity or MCP routing | Registration at load and `session_start`, builtin/MCP/extension ownership and replacement; check guard coverage for direct `mcp__server__tool` arguments and nested codemode calls, including that denied calls never reach the server. |
| TUI, themes or renderer | Check color/key hint helpers for host-bound state, fullscreen input/scrolling, cursor lifecycle, footer, palettes and virtual models. Search both local and resolved third-party code for `super.render()` and render overrides. Trace the concrete base (fresh editor output vs cached container output); propagate readonly results or copy before mutation. |
| Dialog/program status | Audit affected `ctx.ui.custom()` calls. Questions may opt in to `kind: "question"`; loaders remain working, and builtins report their own state. Check hidden overlays until `done()`, plus cleanup on reload/session switch. Classify missed opt-in separately from regressions. For raw OSC checks, use [interactive validation](VALIDATE.md#interactive-target-checks). |
| Persisted settings | Classify new keys as shared preferences or machine-local bookkeeping. Compare `run_once_set-up-pi-settings-filter.sh.tmpl` with `git config --get filter.pi-settings.clean`; the active filter may hide keys from `git diff`. Report needed edits without changing working settings or Git config in review. |

If declarations changed, run [isolated target checks](VALIDATE.md#isolated-target-checks). For changed behavior, name the needed target smoke tests (extension loading, provider/tool routing, or interactive UI/command ownership).

**Done when:** every affected contract is classified against its actual consumers. Separate regressions, pre-existing failures, required migration edits and optional improvements. Record exactly what ran on the target and what remains untested.
