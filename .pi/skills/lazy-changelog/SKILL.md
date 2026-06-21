---
name: lazy-changelog
description: Review lazy.nvim plugin update changelogs with the repo's lazy-changelog scripts.
disable-model-invocation: true
---

# lazy-changelog

Report lazy.nvim plugins where **installed** (current HEAD) differs from
**target** (lazy's update commit), then show the `git log installed..target`
changelog.

## Deterministic run

1. **Start with the overview.** Run:

   ```bash
   bash scripts/lazy-changelog.sh --list
   ```

   Completion criterion: the report shows `outdated=0`, or lists each outdated
   plugin's name, range, and commit count.

2. **Expand only what is needed.** For full changelogs or a focused set:

   ```bash
   bash scripts/lazy-changelog.sh
   bash scripts/lazy-changelog.sh --limit 20 --full
   bash scripts/lazy-changelog.sh pi mitsuhiko-agent-stuff
   ```

   Completion criterion: every requested outdated plugin shows its changelog
   range, or the script reports all requested plugins are up to date.

## Command notes

- The script always re-dumps `specs.tsv` first (headless nvim, ~1s), so specs
  are fresh without any flag — including after editing a plugin spec.
- Reports are based on the on-disk `origin/<branch>` refs, i.e. whatever your
  last Neovim session fetched. They can **underreport** new updates if those
  refs are stale; the changelog dates help you judge freshness. Run `:Lazy check`
  in Neovim for a fast fetch with progress, or pass `--fetch` to have this
  script fetch each plugin itself.

## Environment

The dump step needs a real Neovim binary; this repo's `.pi/sandbox.json` allows
`nvim` via `justBash.hostCommands`, so it runs inside the agent sandbox.

## Files

- `scripts/dump-specs.lua` — runs inside Neovim, emits
  `name|enabled|pin|is_local|dir|skip|installed|target`.
- `scripts/refresh-specs.sh` — writes `~/.cache/lazy-changelog/specs.tsv`.
- `scripts/lazy-changelog.sh` — compares installed/target and prints logs.
