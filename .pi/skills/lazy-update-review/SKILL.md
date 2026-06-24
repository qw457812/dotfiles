---
name: lazy-update-review
description: Review lazy.nvim-managed update changelogs and local config impact.
disable-model-invocation: true
---

# lazy-update-review

Report lazy.nvim-managed packages where **installed** (current HEAD) differs
from **target** (lazy's update commit), show the `git log installed..target`
changelog, and account for any required local config changes.

## Steps

1. **Read the changelog.** Run without filters to see every outdated plugin's
   commits:

   ```bash
   bash scripts/lazy-update-review.sh
   ```

   Completion criterion: every outdated plugin's `installed..target` range and
   commit log has been read. If there are too many to read at once, use `--list`
   only to enumerate/batch plugins, then rerun with plugin filters until every
   listed outdated plugin's log has been read.

2. **Diff a plugin when its changelog is ambiguous about impact.** The header
   carries the install dir (`@ <dir>`), `installed`, and `target`, so:

   ```bash
   git -C <dir> diff <installed>..<target>            # all changes
   git -C <dir> diff <installed>..<target> -- '*.lua' # scope to a path
   ```

   Completion criterion: you can state the diff's impact in one sentence —
   e.g. docs-only, a new config key, a breaking change to an API you use —
   or you decide the changelog alone was enough and skip the diff.

3. **Open the related issue/PR when a commit references one.** Commits often
   carry `#NNNN`; each outdated plugin's header ends with a short host path
   in parens — e.g. `(github.com/olimorris/codecompanion.nvim)`, host kept so
   gitlab/etc plugins aren't misread as github. Prefix `https://` and append
   the ref path:

   ```bash
   # github.com/$repo/pull/<NNNN>   (or /issues/, /compare/inst..tgt)
   # gitlab.com/$group/$repo/-/merge_requests/<NNNN>
   ```

   Completion criterion: every `#NNNN` whose commit message doesn't make the
   change self-evident is read.

4. **Check whether local configs need updates.** Treat `lazy.nvim` as a general
   package manager here: specs may install Neovim plugins, Pi packages, Yazi
   plugins/flavors, or other tools. For every change that mentions changed
   defaults, config keys, commands, events, APIs, build/install steps, or
   integrations you use, first find the owning lazy spec and build hook, then
   check that package's runtime config surface:

   ```bash
   rg -n "<lazy-name>|<repo>|<changed-api-or-key>" dot_config/nvim/lua/plugins
   rg -n "<name>|<module>|<changed-api-or-key>" dot_config/yazi symlinks/yazi                 # Yazi packages
   rg -n "<name>|<module>|<changed-api-or-key>" private_dot_pi/private_agent symlinks/pi/agent # Pi packages
   rg -n "<name>|<module>|<changed-api-or-key>" dot_config private_dot_* symlinks              # fallback
   ```

   Completion criterion: the owning lazy spec, build/install hook, and every
   matching runtime reference are accounted for — still valid, needs a specific
   config edit, or needs a follow-up question to the human.

5. **Update this skill when the config-surface map was incomplete.** If step 4
   missed a package class, owning spec location, build/install hook pattern, or
   runtime config path you had to discover during the review, edit this skill
   before reporting.

   Completion criterion: either step 4 covered every discovered surface, or it
   now names the new surface and the search command that finds it.

## Notes

- The script re-dumps lazy.nvim's computed `installed` and `target` commits, but
  never fetches upstream. Those targets come from the on-disk `origin/<branch>`
  refs — whatever the last Neovim `:Lazy check` fetched — so the report is
  bounded by already-fetched refs and can **underreport** newer updates.
- Never run `:Lazy check` yourself, not even headless `Lazy! check`.
- A non-zero script exit means the changelog review is incomplete; fix or
  report the error before judging any changelog as reviewed.

## Files

- `scripts/lazy-update-review.sh` — the entry point.
- `scripts/dump-plugin-state.lua` — runs inside nvim (needs lazy loaded), invoked by
  the script above.
