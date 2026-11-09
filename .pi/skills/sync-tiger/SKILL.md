---
name: sync-tiger
description: Sync or review updates to the local Rime TigerCode configuration against zhhmn/huma-rime, preserving personal customizations.
disable-model-invocation: true
---

# Sync TigerCode

1. Refresh `zhhmn/huma-rime` using the librarian skill. Record the upstream commit and identify the local baseline from dictionary versions and Git history; compare actual files, not just version strings. Inspect the upstream changelog and all changed files relevant to the enabled `tiger` scheme and its dependencies.
2. Check the working tree and local customizations. Report behavioral changes, conflicts, compatibility risks, and the proposed file-by-file sync before editing. If there are issues or behavior changes, wait for user approval; honor an explicitly approved scope.
3. Copy unchanged-from-upstream files from the checkout into `private_Library/Rime/`. Preserve local patches and user data. For customized upstream files, compare against their upstream baseline, copy the new file when practical, then reapply and verify each customization. Do not restore removed schemes such as `tigress` or rime-ice merely because upstream includes them.
4. Apply only the changed target paths with `chezmoi apply`. Build using `/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer --build "$HOME/Library/Rime" '/Library/Input Methods/Squirrel.app/Contents/SharedSupport' "$HOME/Library/Rime/build"`. Check output for errors and verify the expected schema and rebuilt dictionaries exist; a zero exit code alone is insufficient.
5. Review the diff against upstream and the original local state. Report the upstream revision, changes, retained customizations, validation and any interactive tests still needed. Do not stage or commit unless requested.

## Local context

- `tiger.custom.yaml` and global `*.custom.yaml` contain personal keybindings and appearance; upstream replacements can erase them. Scheme-level bindings override global bindings.
- `tiger.extended.dict.yaml` intentionally disables the single-code alternative symbols. Preserve that change when syncing upstream.
- `PY_c` is the pinyin reverse lookup; `core2022`, `easy_english`, Lua and OpenCC files can be shared dependencies. The official `emoji_cn` option name is distinct from the `opencc/emoji.json` resource filename.
- Preserve `~/Library/Rime` user databases, sync data and its separate Git repository. The retained emacs-rime configuration is historical and may not deploy without its own shared defaults.
