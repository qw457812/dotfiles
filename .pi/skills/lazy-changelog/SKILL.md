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

1. **Read the changelog.** Run without filters to see every outdated plugin's
   commits:

   ```bash
   bash scripts/lazy-changelog.sh
   ```

   Completion criterion: every outdated plugin shows its `installed..target`
   range and commit log. If there are too many to read at once, narrow with
   `--list` (names + counts only) or a plugin filter first.

2. **Diff a plugin when its changelog is ambiguous about impact.** The header
   carries the install dir (`@ <dir>`), `installed`, and `target`, so:

   ```bash
   git -C <dir> diff <installed>..<target>            # all changes
   git -C <dir> diff <installed>..<target> -- '*.lua' # scope to a path
   ```

   Completion criterion: the change in the files is understood, or you decide
   the changelog alone was enough (skip this plugin's diff).

3. **Open the related issue/PR when a commit references one.** Commits often
   carry `#NNNN`; the plugin's origin URL is in `specs.tsv` (re-dumped every
   run), so derive owner/repo and read the thread for context the changelog
   omits:

   ```bash
   url=$(grep -m1 "^<plugin>|" "$HOME/.cache/lazy-changelog/specs.tsv" | cut -d'|' -f5)
   repo=$(printf '%s' "$url" | sed 's#.git$##; s#.*github.com[:/]##')   # owner/repo
   # open github.com/$repo/pull/<NNNN> (or /issues/)
   ```

   Completion criterion: every `#NNNN` you needed context on is read.

## Command notes

- Reports are based on the on-disk `origin/<branch>` refs, i.e. whatever your
  last Neovim session fetched. They can **underreport** new updates if those
  refs are stale; the changelog dates help you judge freshness. Run `:Lazy check`
  in Neovim for a fast fetch with progress, or pass `--fetch` to have this
  script fetch each plugin itself.

## Files

- `scripts/dump-specs.lua` — runs inside Neovim, emits
  `name|pin|is_local|dir|url|skip|installed|target`.
- `scripts/refresh-specs.sh` — writes `~/.cache/lazy-changelog/specs.tsv`.
- `scripts/lazy-changelog.sh` — compares installed/target and prints logs.
