# Pi runtime and extension compatibility

Follow this branch when `earendil-works/pi` changes, alongside prompt-editor review.
Reuse that branch's frozen lazy and published npm revisions; inspect every distinct
exact range. The lazy build hook and the installed CLI can track different releases.

## 1. Find runtime consumers

Locate the owning lazy spec/build hook and all local API consumers:

```bash
rg -n 'earendil-works/pi|pi update' dot_config/nvim/lua/plugins
rg -n '@earendil-works/pi-|registerProvider|registerTool|registerCommand|mcp__|sourceInfo|defaultTools|virtual|mcpServers|exposure' private_dot_pi/private_agent symlinks/pi/agent .pi --glob '!package-lock.json' --glob '!skills/**'
rg -n '"@earendil-works/pi-' private_dot_pi/private_agent --glob '*package*.json'
```

Read settings, model definitions, extension sources, and dependency pins implicated
by the exact-range diffs. Include project `.pi/settings.json` and `.pi/mcp.json`
when present, alongside the global config; project MCP exposure and names can
change the runtime loadout even when the global `mcpServers` is empty. For
third-party integrations, resolve the package actually loaded by settings and inspect its installed source, including `node_modules` paths
normally ignored by `rg`.

**Complete when:** each changed API's local consumers and package ownership are
recorded, including third-party consumers and separately pinned development types.

## 2. Inspect changed integration contracts

Inspect exact-range diffs covering:

- Provider/model configuration types, root exports, model-cache unions, chat/image/
  classifier discrimination, provider events, and auth/default-model changes.
- Extension/tool contexts, nested tool events, cancellation, and tool-name/input
  routing used by sandbox and guard extensions.
- Builtin extension identity and command registration in both load and
  `session_start` phases. Check MCP command ownership and replacement
  semantics alongside installed extensions.
- TUI terminal-color helpers, theme APIs and palettes, fullscreen input/scrolling,
  cursor lifecycle, footer rendering, and virtual-model routing.

For MCP changes, verify that local guards inspect direct `mcp__server__tool`
arguments and apply to nested codemode calls. Verify that blocked calls never
reach the server.

When declarations change, validate local extensions against the frozen target
package declarations in a temporary tree. Preserve installed packages and source
pins during review. A check against current dependencies proves only the baseline;
report target-only errors separately from runtime failures.

**Complete when:** every changed contract with a local consumer is classified as
compatible, requiring a specific edit, or intentionally unsupported. Distinguish
existing breakage from optional-new-feature gaps and migration prerequisites.

## 3. Report follow-up checks

Name required source/type-pin edits and package choices without installing them.
After installation, require the repository's Pi check/lint/test scripts, extension
loading and provider/tool smoke tests, and fixed-size tmux checks for affected UI
or command ownership. Reuse prompt-editor's interactive checklist when applicable.

**Complete when:** each finding names its affected path and required follow-up;
review-only runs leave runtime packages and local runtime configuration unchanged.
