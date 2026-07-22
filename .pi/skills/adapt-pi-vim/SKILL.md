---
name: adapt-pi-vim
description: Adapt a pi extension that extends pi-vim's ModalEditor to newer pi-vim versions. Covers type changes, cursor shape conflict resolution, ex-command support, and pi-managed path resolution. Use when pi-vim has a breaking API change and an extension subclassing ModalEditor (e.g., prompt-editor) needs updating.
disable-model-invocation: true
---

# Adapt pi-vim changes

When pi-vim bumps to a new version, extensions subclassing `ModalEditor` must be checked
for compatibility. Reference: `extensions/prompt-editor/index.ts`.

## Quick start

```bash
# Find installed pi-vim version
cat ~/.pi/agent/npm/node_modules/pi-vim/package.json | head -3

# Upgrade pi-vim (always use pi's package manager, never npm directly)
pi update --extension npm:pi-vim

# Ensure repo is cached via librarian, then compare changelogs
bash ~/.pi/agent/git/github.com/mitsuhiko/agent-stuff/skills/librarian/checkout.sh \
  github.com/lajarre/pi-vim --path-only
# Find the commit for the old version (pi-vim uses chore(release) commits, not tags)
CHK=~/.cache/checkouts/github.com/lajarre/pi-vim
OLD_REV=$(git -C "$CHK" log --oneline --all --grep="bump version to $(cat ~/.pi/agent/npm/node_modules/pi-vim/package.json | head -3 | grep version | sed 's/.*"\([^"]*\)".*/\1/')" | head -1 | cut -d' ' -f1)
# View changes to index.ts since old version
git -C "$CHK" log --oneline ${OLD_REV}..HEAD -- index.ts
# Or diff a specific file
git -C "$CHK" diff ${OLD_REV}..HEAD -- index.ts
```

> **Never** run `cd ~/.pi/agent/npm && npm install pi-vim@latest` — that bypasses pi's
> version checking and settings integration. Use `pi update --extension npm:pi-vim` instead.
> If you need to revert, use `pi install npm:pi-vim@<version>`.

## Assess impact first

Before touching extension code, diff the old and new pi-vim via the librarian
cached repo to determine if any **public API** changed. Many minor bumps only
add internal features and need zero extension changes.

```bash
# View changelog of index.ts between versions
CHK=~/.cache/checkouts/github.com/lajarre/pi-vim
# OLD_REV = commit hash of the previously installed version
# Find it with: git -C "$CHK" log --oneline --all --grep="bump version to <old-version>"
git -C "$CHK" log --oneline ${OLD_REV}..HEAD -- index.ts

# Check full diff for API surface changes
git -C "$CHK" diff ${OLD_REV}..HEAD -- index.ts | rg "^[+-]" | rg -v "^[+-]{3}" |
  rg "(ModalEditorOptions|setQuitFn|setNotifyFn|setClipboardFn|setRegister|cursorShapeRuntime|pendingExCommand|labelColorizer|borderColorizer)" || echo "No API surface changes found"
```

If the diff shows no API changes, the extension likely needs no code changes — just update
`package.json` and verify with `npm run check && npm run lint`.

For a complete overview of all changed source files (not just index.ts):

```bash
git -C "$CHK" log --oneline --diff-filter=AMR ${OLD_REV}..HEAD -- \
  ":(exclude)test/*" ":(exclude)*.md" ":(exclude)*.json"
git -C "$CHK" diff --stat ${OLD_REV}..HEAD -- \
  ":(exclude)test/*" ":(exclude)*.md" ":(exclude)*.json"
```

## Workflow checklist

1. [ ] **Resolve pi-vim path** — use `getAgentDir()` not `npm root -g`（see REFERENCE #1）
2. [ ] **Update constructor call** — check if `super()` switched from positional args to an options bag（see REFERENCE #2）
3. [ ] **Check labelColorizers / borderColorizers** — newer pi-vim may add required fields like `ex` or new options like `borderColorizers`（see REFERENCE #3）
4. [ ] **Disable built-in cursor shape** — if pi-vim added `cursorShapeRuntime`, null it in constructor（see REFERENCE #4）
5. [ ] **Ex-command passthrough** — if `pendingExCommand` was added, bypass remaps in `handleInput`（see REFERENCE #5）
6. [ ] **Derive active mode** — extract `getActiveMode()` helper so label/prefix colorizers use the correct mode（see REFERENCE #6）
7. [ ] **Check mode unions and colorizers** — add new modes such as `visual` / `visual-line`, normalize them to the corresponding color key, and choose their cursor shape（see REFERENCE #9）
8. [ ] **Mirror the complete session setup** — a replacement editor must reapply clipboard policy, mode-change hooks, ex settings, and the dynamic command registry, not only quit/notify callbacks（see REFERENCE #10）
9. [ ] **Define `ModalEditorRuntime`** — structural type for safe private field access（see REFERENCE #7）
10. [ ] **Adopt cursor stripping helpers** — `findSoftwareCursorReset` + `stripSoftwareCursorAfterMarker`（see REFERENCE #8）
11. [ ] **Update `package.json` version pin** — change `"pi-vim": "<old>"` to the new version, then run `npm install` to sync the lockfile

## Update package.json & install

After upgrading pi-vim and (if needed) adapting extension code, update the
version pin in `package.json` and sync the lockfile:

```bash
# Edit the version pin (e.g. "pi-vim": "0.11.0" → "0.11.1")
# Then install to update package-lock.json
cd ~/.pi/agent && npm install
```

This step is required even when no extension code changed — `package.json`
must reflect the actual installed version so future `npm install` runs are
reproducible.

## Verify

```bash
cd ~/.pi/agent && npm run check    # tsc --noEmit
cd ~/.pi/agent && npm run lint     # oxlint
```

To inspect the original pi-vim UI without auto-discovered extensions such as
`prompt-editor`, start Pi with only the installed pi-vim entry explicitly loaded:

```bash
pi --no-session --no-extensions -e ~/.pi/agent/npm/node_modules/pi-vim/index.ts
```

## After adapting

Update this skill with any new patterns discovered during the migration.
New pi-vim versions may introduce API surfaces not covered here.

See [REFERENCE.md](REFERENCE.md) for code samples and detailed explanations.
