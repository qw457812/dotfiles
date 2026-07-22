---
name: adapt-pi-vim
description: Adapt prompt-editor to a newer pi-vim version.
disable-model-invocation: true
---

# Adapt pi-vim

Upgrade the pi-managed `pi-vim` package and keep the chezmoi-owned
`PromptEditor extends ModalEditor` integration compatible.

Paths:

- source extension: `private_dot_pi/private_agent/extensions/prompt-editor/index.ts`
- source version pin: `private_dot_pi/private_agent/package.json`
- installed package: `~/.pi/agent/npm/node_modules/pi-vim`
- detailed compatibility patterns: [REFERENCE.md](REFERENCE.md)

## 1. Freeze the published package revisions

Resolve both revisions from npm's `gitHead` metadata so the diff matches the code
shipped in the installed and target tarballs:

```bash
set -euo pipefail
OLD_VERSION=$(node -p 'require(process.env.HOME + "/.pi/agent/npm/node_modules/pi-vim/package.json").version')
TARGET_VERSION=$(npm view pi-vim version)
OLD_REV=$(npm view "pi-vim@$OLD_VERSION" gitHead)
TARGET_REV=$(npm view "pi-vim@$TARGET_VERSION" gitHead)
CHK=$(bash ~/.pi/agent/git/github.com/mitsuhiko/agent-stuff/skills/librarian/checkout.sh \
  github.com/lajarre/pi-vim --path-only)
git -C "$CHK" cat-file -e "$OLD_REV^{commit}"
git -C "$CHK" cat-file -e "$TARGET_REV^{commit}"
printf 'installed=%s\nold=%s\ntarget_version=%s\ntarget=%s\n' \
  "$OLD_VERSION" "$OLD_REV" "$TARGET_VERSION" "$TARGET_REV"
```

**Complete when:** both versions and non-empty `gitHead` revisions are recorded,
both revisions exist in the cached repository, and `OLD_REV..TARGET_REV` is the
published-package range to review.

## 2. Review the whole change surface

```bash
git -C "$CHK" log --oneline "$OLD_REV..$TARGET_REV"
git -C "$CHK" diff --stat "$OLD_REV..$TARGET_REV"
git -C "$CHK" diff "$OLD_REV..$TARGET_REV" -- \
  index.ts types.ts settings.ts clipboard-policy.ts mode-colors.ts \
  mode-change-command.ts cursor-shape.ts
```

Account for changes to:

- `ModalEditor` constructor, public setters, modes, and private fields accessed structurally
- `default` extension `session_start` / `session_shutdown` setup
- settings, colorizer keys, command dispatch, clipboard behavior, and cursor rendering
- exported or moved helpers copied or re-exported by `prompt-editor`

Read only the matching headings in [REFERENCE.md](REFERENCE.md) once the changed
surfaces are known.

**Complete when:** every changed integration surface is classified as compatible,
requiring a concrete edit, or intentionally unsupported with a stated reason.

## 3. Upgrade both package installations

Use Pi for its managed installation, then confirm it installed the frozen target:

```bash
pi update --extension npm:pi-vim
test "$(node -p 'require(process.env.HOME + "/.pi/agent/npm/node_modules/pi-vim/package.json").version')" = \
  "$TARGET_VERSION"
```

Then update the exact `pi-vim` pin to `TARGET_VERSION` in
`private_dot_pi/private_agent/package.json` and sync the chezmoi source lockfile:

```bash
cd private_dot_pi/private_agent
npm install
```

Use `pi install npm:pi-vim@<version>` to restore a specific managed version.

**Complete when:** the installed package, source `package.json`, source lockfile,
and source `node_modules/pi-vim` report the same target version.

## 4. Adapt prompt-editor

Apply only the compatibility patterns triggered by step 2. Regenerate the local
`pi-vim.generated.ts` wrapper by loading Pi after changing its template; the wrapper
must resolve the pi-managed package, not the source-tree dev dependency.

For a replacement editor, compare pi-vim's complete factory setup rather than only
its constructor. Preserve project/global settings trust boundaries from upstream.

**Complete when:** every surface classified for editing in step 2 is implemented,
the generated wrapper points at the target installation, and no changed upstream
setup setter or cleanup hook is unaccounted for.

## 5. Verify

```bash
cd private_dot_pi/private_agent
npm run check
npm run lint
cd -
pi --list-models >/dev/null
```

Inspect upstream pi-vim without auto-discovered extensions when UI comparison is
needed:

```bash
pi --no-session --no-extensions -e ~/.pi/agent/npm/node_modules/pi-vim/index.ts
```

Manually exercise every changed interactive branch, such as mode transitions,
rendering, Ex dispatch, clipboard policy, and settings overrides.

**Complete when:** typecheck, lint, runtime loading, and every affected interactive
branch pass against the target version.

## 6. Keep this skill current

Add a new reference pattern only when the migration discovers a reusable integration
surface not already covered; replace stale guidance rather than layering it.

**Complete when:** [REFERENCE.md](REFERENCE.md) covers every reusable pattern learned
from the migration with one source of truth per pattern.
