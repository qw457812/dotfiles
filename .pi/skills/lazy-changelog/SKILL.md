---
name: lazy-changelog
description: Review lazy.nvim plugin update changelogs with the repo's lazy-changelog scripts.
disable-model-invocation: true
---

# lazy-changelog

Use this skill to report lazy.nvim plugins whose installed commit differs from
lazy's update target, then show the `git log installed..target` changelog.

## Deterministic run

1. **Confirm freshness.** The human should run `:Lazy check` in Neovim first.
   Completion criterion: origin refs have been refreshed by lazy.nvim, or the
   user explicitly accepts cached/offline results.

2. **Ensure the spec dump exists.** If `~/.cache/lazy-changelog/specs.tsv` is
   missing, or plugin specs changed, run:

   ```bash
   bash scripts/refresh-specs.sh
   ```

   Completion criterion: the command exits 0 and reports a non-zero plugin
   count. The dump is produced by Neovim using lazy's own `Git.info` and
   `Git.get_target`, so `version="*"`, `commit`, `tag`, `pin`, disabled, and
   local/dev plugin rules match `:Lazy check`.

3. **Start with the overview.** Run:

   ```bash
   bash scripts/lazy-changelog.sh --list
   ```

   Completion criterion: report either `outdated=0` or the listed plugin names,
   ranges, and commit counts.

4. **Expand only what is needed.** For full changelogs or focused output, run:

   ```bash
   bash scripts/lazy-changelog.sh
   bash scripts/lazy-changelog.sh --limit 20 --full
   bash scripts/lazy-changelog.sh pi mitsuhiko-agent-stuff
   ```

   Completion criterion: every requested outdated plugin has its changelog range
   shown, or the script reports all requested plugins are up to date.

## Command notes

- `--refresh` regenerates `specs.tsv` before comparing; it needs Neovim.
- `--fetch` fetches plugin repos, regenerates specs, then compares. It is
  redundant after a fresh `:Lazy check`.
- Default mode is offline and reuses the refs from the last `:Lazy check`.
- The script auto-refreshes the specs cache when it detects staleness — i.e.
  when `:Lazy check` or a `:Lazy update/sync/restore` (which rewrites
  `lazy-lock.json`) has run since the last dump. No `--refresh` needed in the
  normal flow; pass `--no-refresh` to force a fast offline query trusting the
  existing cache.

## Environment

The query script is pure shell + git after the dump exists. The dump step needs
a real Neovim binary; this repo's `.pi/sandbox.json` allows `nvim` via
`justBash.hostCommands`, so it can run inside the agent sandbox. The scripts are
written for Termux's restricted `bash` and avoid process substitution, `trap`,
and `jq`.

## Files

- `scripts/dump-specs.lua` — runs inside Neovim and emits
  `name|enabled|pin|is_local|dir|skip|installed|target`.
- `scripts/refresh-specs.sh` — writes `~/.cache/lazy-changelog/specs.tsv`.
- `scripts/lazy-changelog.sh` — compares `installed`/`target` and prints logs.
