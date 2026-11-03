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
third-party integrations, resolve the package actually loaded by settings, then
search its entry/source directories explicitly, including ignored installed files:

```bash
rg -n --no-ignore '<changed-api>' <resolved-package-entry-or-source-directory>
```

A normal repository search can miss every consumer below `node_modules`.

When upstream adds persisted settings state, include the repository's Git clean
filter as a config surface:

```bash
rg -n 'pi-settings|deviceId|lastChangelogVersion|extensionChangelogVersions' run_once_set-up-pi-settings-filter.sh.tmpl .gitattributes symlinks/pi/agent/settings.json
git config --get filter.pi-settings.clean
```

Classify new keys as shareable preferences or machine-local bookkeeping (for
example changelog read receipts). Check both the filter template and active Git
config; a clean `git diff` may merely mean the filter hides a key. Review reports
name required filter edits without deleting runtime state or changing Git config.

**Complete when:** each changed API's local consumers and package ownership are
recorded, including third-party consumers, separately pinned development types,
and persistence filters for new settings state.

## 2. Inspect changed integration contracts

Inspect exact-range diffs covering:

- Provider/model configuration types, root exports, model-cache unions, chat/image/
  classifier discrimination, provider events, and auth/default-model changes.
- Extension/tool contexts, nested tool events, cancellation, and tool-name/input
  routing used by sandbox and guard extensions. For schema changes, compare the
  extension loader's import aliases with direct TypeScript imports: runtime shims
  can preserve compatibility while standalone checks see different builders or
  inferred argument types. Check JSON schema shape and coercion/refinement behavior,
  not only whether imports still resolve.
- Builtin extension identity and command registration in both load and
  `session_start` phases. Check MCP command ownership and replacement
  semantics alongside installed extensions.
- TUI terminal-color helpers, theme APIs and palettes, fullscreen input/scrolling,
  cursor lifecycle, footer rendering, and virtual-model routing. When renderer
  contexts gain host-bound helpers, locate imported equivalents such as `keyHint`;
  extension-local package copies may not share host state.
- New UI status APIs: inspect every matching `ctx.ui.custom()` use and distinguish
  user decisions from loaders or viewers. For `blocked`, inline questions can use
  `kind: "question"`; loaders remain working, overlays ignore the option, and
  built-in dialogs already report their own status. Classify adoption as an optional
  integration improvement rather than an execution regression; apply needs consent.

For MCP changes, verify that local guards inspect direct `mcp__server__tool`
arguments and apply to nested codemode calls. Verify that blocked calls never
reach the server.

When declarations change, validate against the frozen target in an isolated source
copy. Preserve installed packages and source pins during review:

- Place the copy under `~/.cache`, outside `os.tmpdir()`. The sandbox permits writes
  to the system temp directory, so putting read-only test fixtures there makes
  permission assertions fail for reasons unrelated to the target release.
- Copy sources without `node_modules`; install exact target host packages at the
  temporary root. Find nested manifests with
  `rg --files private_dot_pi/private_agent -g package.json` and place their runtime
  dependencies at that root too, so nested host pins cannot select old declarations.
- Preserve unrelated dependency resolutions from the baseline locks/installed
  packages, including promoted nested dependencies. Record discrepancies between
  locks and actual installs; resolving every caret range afresh confounds the review.
- Record the resolved compiler/linter executable and its own `--version`, including
  `.bin` symlink targets; `package.json` versions do not identify the tool actually
  run. Missing native platform packages (for example TypeScript on Android) are
  environment failures. If a compatible baseline tool runs against target
  declarations, name its version and limitations; do not claim the declared target
  toolchain passed.

Run the unmodified tests first. Record hardcoded host-version failures and event
fixture/type errors, then make only the required test adaptations in the temporary
copy and rerun check and the behavioral suite. Report original and adapted results
separately from runtime regressions; test adaptations remain required source edits.

Tie results to the copied source state. If local consumers change concurrently,
revalidate the affected latest sources before claiming they passed; leave the
unrelated work untouched.

**Complete when:** every changed contract with a local consumer is classified as
compatible, requiring a specific edit, or intentionally unsupported. Distinguish
existing breakage from optional-new-feature gaps and migration prerequisites.

## 3. Report follow-up checks

Name required source/type-pin edits and package choices without installing them.
After installation, require the repository's Pi check/lint/test scripts, extension
loading and provider/tool smoke tests, and fixed-size tmux checks for affected UI
or command ownership. For program-status changes, capture raw OSC 7501 with
`PI_PROGRAM_STATUS=1`: assert the intended blocked kind/message while the dialog is
visible and restoration after completion or cancellation; verify loaders are not
misreported. Reuse prompt-editor's interactive checklist when applicable.

**Complete when:** each finding names its affected path and required follow-up;
review-only runs leave runtime packages and local runtime configuration unchanged.
