---
name: lazy-update-review
description: Review pending lazy.nvim package updates against local configuration.
disable-model-invocation: true
---

# Lazy update review

Review the packages named by the caller, or all eligible packages if none are named. Leave installations and runtime configuration unchanged unless the caller explicitly requests an apply.

## 1. Establish the review range

Run `bash .pi/skills/lazy-update-review/scripts/lazy-update-review.sh` from the chezmoi root, appending only the requested **exact lazy names** (e.g. `pi`). The script compares installed HEAD with lazy's target from on-disk refs. This is **not** a check for the latest upstream commit. Never run `:Lazy check`, including headless `Lazy! check`.

Keep the footer and each outdated package's `installed..target`, checkout directory and host/repo from its header. Read the full commit log for each range. For a large report, use `--list` with the same scope to plan batches, then read the uncapped logs by name. A list or a `--limit` sample is not a reviewed log.

**Done when:** the scan succeeds, every requested name is accounted for, and every outdated log in scope has been read. Check an uncertain name on its own: a mixed filter can succeed on one match. Report skipped or ignored entries as unchecked; `scanned=0` means nothing was checked. On nonzero exit, fix or report the incomplete scan.

## 2. Trace each update to its consumer

Find the owning spec in `dot_config/nvim/lua/plugins` and follow its build hook (or record that it has none). Lazy may manage a source checkout, a separately installed executable, a Pi package or a Yazi flavor. Search for changed defaults, keys, commands, events, APIs and install steps where the package **runs**, not just in its lazy spec. For example, Yazi consumers live under `dot_config/yazi` and `symlinks/yazi`; Pi has both project `.pi/` and global config.

Match the **host/repo in the header** against this table. Do the additional reviews even if the changelog claims compatibility. Run each matching branch once across the in-scope packages; unmatched packages need only the generic review.

| Report repository | Additional review, in order |
| --- | --- |
| `github.com/neovim/neovim` | [Neovim executable vs. source checkout](surfaces/neovim-runtime/REVIEW.md) |
| `github.com/earendil-works/pi` | [Prompt-editor and frozen release ranges](surfaces/prompt-editor/REVIEW.md), then [Pi runtime consumers](surfaces/pi-runtime/REVIEW.md) |
| `github.com/lajarre/pi-vim` | [Prompt-editor and frozen release ranges](surfaces/prompt-editor/REVIEW.md) |
| `github.com/deepseek-ai/deepseek-harness` | [DSH CLI and profile composition](surfaces/deepseek-harness/REVIEW.md) |
| `github.com/ccch1mneyyy/dsh-TUI` | [DSH profile package](surfaces/dsh-profile-package/REVIEW.md) |

For an ambiguous changelog, read `git -C <checkout> diff <installed>..<target>`, narrowing to affected paths as needed. Use the branch's frozen hashes and source cache where specified. Open each referenced issue or PR whose change the commit does not explain, on the **reported host** (GitHub `/pull/N` or `/issues/N`; GitLab `/-/merge_requests/N`).

**Done when:** for every outdated package, the spec, build hook, affected runtime references and matching branch checks have a finding: still valid, a specific edit at a named path, or an unresolved question with the evidence needed to answer it.

## 3. Hand off the review

Report scope, scan counts and findings against the recorded ranges. A filtered scan says nothing about other packages. The report is complete when every finding names its evidence (static or tested on an exact target) and any required follow-up or blocker.

For an explicit apply, verify installed hashes and runtime versions against the record first. If the user updated meanwhile, reuse the recorded range; a fresh `outdated=0` is not compatibility evidence. Ask for a missing old revision/version; review any different target before proceeding. For Pi or pi-vim, use the [frozen-target apply procedure](surfaces/prompt-editor/APPLY.md) only for the changes authorized.

Change this skill only if correcting stale guidance or adding a check would prevent a repeat miss. Put one-off findings in the report. Add a specialized branch under `surfaces/<name>/` and to the table only when generic tracing is insufficient.
