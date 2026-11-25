---
name: sync-tiger
description: Sync or review updates to the local Rime TigerCode configuration against zhhmn/huma-rime, preserving personal customizations.
disable-model-invocation: true
---

# Sync TigerCode

1. Refresh `zhhmn/huma-rime` using the librarian skill. Record the upstream commit and identify the local baseline from dictionary versions and Git history; compare actual files, not just version strings. Inspect the upstream changelog and all changed files relevant to the enabled `tiger` scheme and its dependencies.
2. Check the working tree and local history across `private_Library/Rime/`, `dot_local/share/fcitx5/rime/`, `dot_config/trime/`, and `run_onchange_after_sync-trime-config.sh.tmpl`. Compare every affected local file against both the recorded upstream baseline and the new upstream revision; identify local customizations and platform-specific effects on templates, keybindings, themes, and deployment. Report behavioral changes, conflicts, compatibility risks, and the proposed file-by-file sync before editing. If there are issues or behavior changes, wait for user approval; honor an explicitly approved scope.
3. Copy unchanged-from-upstream files from the checkout into `private_Library/Rime/`. Preserve local patches and user data. For customized upstream files, compare against their upstream baseline, copy the new file when practical, then reapply and verify each customization. Do not restore removed schemes such as `tigress` or rime-ice merely because upstream includes them.
4. Verify every affected frontend template renders its shared files and required Lua modules, including platform-specific `includeTemplate` branches. Inspect the Trime sync script before applying on Android: its current `rsync --delete` can remove unmanaged mirror files. Apply only the changed target paths with `chezmoi apply` when safe. On macOS, build using `/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer --build "$HOME/Library/Rime" '/Library/Input Methods/Squirrel.app/Contents/SharedSupport' "$HOME/Library/Rime/build"`. Check output for errors and verify the expected schema and rebuilt dictionaries exist; a zero exit code alone is insufficient. Test other available frontends on their platforms and report those not tested.
5. Review the diff against upstream and the original local state. Update the baseline recorded below after a successful sync. Report the upstream revision, changes, retained customizations, validation and any interactive tests still needed. Do not stage or commit unless requested; if committing, include the upstream commit in the commit message.

## Local context

- Last upstream baseline: [zhhmn/huma-rime `fafb978e739fe41d91e02f35290f81c42b5f6162`](https://github.com/zhhmn/huma-rime/commit/fafb978e739fe41d91e02f35290f81c42b5f6162), synced in chezmoi commit `cb1d79f0` (2026.08.15 data). This records the upstream data baseline, not the latest dotfiles state; inspect subsequent Rime, fcitx5 and Trime commits before syncing.
- `tiger.custom.yaml` and global `*.custom.yaml` contain personal keybindings and appearance; upstream replacements can erase them. Scheme-level bindings override global bindings. `default.custom.yaml.tmpl` selects different ASCII switch keys for Squirrel and fcitx5; preserve platform branches.
- The shared tiger processor list loads `lua/vim_mode.lua`; keep that module available to each frontend. It implements fcitx5-specific behavior while Squirrel handles its own Vim mode.
- `tiger.extended.dict.yaml` intentionally disables the single-code alternative symbols. Preserve that change when syncing upstream.
- `PY_c` is the pinyin reverse lookup; `core2022`, `easy_english`, Lua and OpenCC files can be shared dependencies. The official `emoji_cn` option name is distinct from the `opencc/emoji.json` resource filename.
- Preserve `~/Library/Rime` user databases, sync data and its separate Git repository.
