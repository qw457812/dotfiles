---
name: lazy-changelog
description: Report pending changelogs for lazy.nvim plugins that are behind their update target, matching :Lazy check's "Updates" exactly. Use after running :Lazy check to review what commits new plugin versions bring before updating. Computes installed vs target using lazy's own Git.info/Git.get_target (so version="*", commit pins, tag pins, disabled, dev/local plugins are all handled correctly). No Neovim needed at query time; a one-time spec dump is required.
disable-model-invocation: true
---

# lazy-changelog

Lists lazy.nvim plugins behind their update target and shows the changelog of
the commits an update would pull. Output is designed to match `:Lazy check`'s
"Updates" panel exactly.

## How "outdated" is decided

For each plugin we compare two commits **computed by lazy itself**:

| commit     | source                                            |
|------------|---------------------------------------------------|
| `installed`| `Git.info(plugin.dir).commit` (= current `HEAD`)  |
| `target`   | `Git.get_target(plugin).commit` (lazy's target)   |

`installed != target` ⇒ outdated; changelog = `git log installed..target`
(the same range lazy's `log` task uses). This delegates every spec nuance —
`version="*"`, `commit="..."`, `tag="..."`, `pin`, `enabled=false`, dev/dir
plugins, and the `defaults.version` fallback — to lazy's own code, so the
result matches `:Lazy check` instead of approximating it.

Compare with an earlier approach that compared the `lazy-lock.json` commit to
`origin/<branch>`: that reported drift/lockfile staleness, **not** what lazy
considers outdated, so it produced false positives (version-pinned plugins
like `blink.cmp`, `yazi.nvim`; commit-pinned ones like `oh-my-tmux`) and false
negatives.

## Workflow

```bash
# 1. in Neovim: refresh upstream refs
:Lazy check

# 2. (once, or after changing your plugin specs) regenerate the specs cache:
bash scripts/refresh-specs.sh
#   -> writes ~/.cache/lazy-changelog/specs.tsv via headless nvim

# 3. show pending changelogs (offline, instant):
bash scripts/lazy-changelog.sh
#   or, auto-refresh the cache first if missing:
bash scripts/lazy-changelog.sh --refresh
```

The dump (`refresh-specs.sh`) needs Neovim because lazy resolves specs at
load time (e.g. `version = not vim.g.lazyvim_blink_main and "*"`, dynamic
`enabled`). The default query (`lazy-changelog.sh`) is pure offline git and
needs no Neovim, reusing the origin refs `:Lazy check` just fetched.
`--refresh` and `--fetch` regenerate the specs cache and therefore need Neovim.

## Usage

```bash
bash scripts/lazy-changelog.sh [--refresh] [--fetch] [--full] [--limit N] [plugin ...]

# only these plugins
bash scripts/lazy-changelog.sh blink.cmp yazi.nvim

# cap length, show dates/authors
bash scripts/lazy-changelog.sh --limit 20 --full
```

Options: `--refresh` (regenerate specs cache first), `--fetch` (git-fetch per
plugin, then regenerate specs before comparing — redundant after `:Lazy check`),
`--full`, `--limit N`, `-h/--help`. Env overrides: `SPEC_FILE`, `NVIM`.

Each outdated plugin is printed as a `## name  installed..target` header
followed by its `git log` commits. A `scanned=… outdated=…` summary goes to
stderr.

## Files

- `scripts/dump-specs.lua` — runs inside nvim; emits
  `name|enabled|pin|is_local|dir|skip|installed|target` per plugin, where
  `installed`/`target` come from lazy's `Git.info`/`Git.get_target`.
- `scripts/refresh-specs.sh` — headless wrapper around `dump-specs.lua`;
  writes `specs.tsv`.
- `scripts/lazy-changelog.sh` — offline comparison + `git log installed..target`.

## Environment notes

Written for Termux's restricted `bash` (no `trap`, no process substitution)
and runs without `jq`: specs are pre-serialized TSV, iteration uses
`printf|while read`, and `git log -n` (not `head`) avoids SIGPIPE killing the
scan loop. The dump step requires Neovim (it cannot run in the agent sandbox,
but runs fine in your interactive shell).

## Related lazy.nvim internals

- `lua/lazy/manage/checker.lua` — `fast_check()` (the offline comparison this
  script mirrors) and `M.check()` (the fetch version).
- `lua/lazy/manage/git.lua` — `Git.info`, `Git.get_target`, `Git.eq`.
- `lua/lazy/manage/task/git.lua` — `log` task (`from..to` = `installed..target`).
- `~/.local/state/nvim/lazy/state.json` — stores only `checker.last_check`
  (the frequency gate); the outdated set is never persisted, always recomputed
  from git refs — which is why this script can replicate it offline.
