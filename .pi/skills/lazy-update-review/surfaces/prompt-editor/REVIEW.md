# Prompt-editor compatibility branch

Follow this branch only when the lazy review includes `earendil-works/pi` or
`lajarre/pi-vim`. `PromptEditor extends ModalEditor` depends on private runtime
surfaces from both repositories. Review checkout and runtime ranges separately:
lazy tracks both repositories, Pi's build hook installs its npm release, and the
pi-vim runtime is managed independently through Pi settings.

Paths:

- source extension: `private_dot_pi/private_agent/extensions/prompt-editor/index.ts`
- source package pins: `private_dot_pi/private_agent/package.json`
- reusable source caches: librarian checkouts for `earendil-works/pi` and
  `lajarre/pi-vim`
- pi-vim runtime: `~/.pi/agent/npm/node_modules/pi-vim`

The lazy working trees normally remain on their **installed** revisions. Copy only
the immutable revision hashes from the report; inspect those exact hashes in fresh
librarian caches instead of reading or mutating the lazy working trees.

## 1. Freeze the applicable ranges

Copy each changed package's installed and target revisions from its lazy report
header. Do not check out the target or mutate the lazy working tree. For Pi:

```bash
PI_LAZY_OLD_REV='copy Pi installed revision from header'
PI_LAZY_TARGET_REV='copy Pi target revision from header'
```

Freeze the Pi release endpoint used by `pi update --self`, then resolve that exact
published package revision:

```bash
set -euo pipefail
PI_OLD_VERSION=$(pi --version)
PI_RELEASE_JSON=$(curl -fsSL https://pi.dev/api/latest-version)
read -r PI_TARGET_PACKAGE PI_TARGET_VERSION < <(
  node -e '
    const fs = require("node:fs");
    const value = JSON.parse(fs.readFileSync(0, "utf8"));
    if (value.ok !== true || typeof value.packageName !== "string" || typeof value.version !== "string") {
      throw new Error("invalid Pi release metadata");
    }
    process.stdout.write(`${value.packageName} ${value.version}\n`);
  ' <<<"$PI_RELEASE_JSON"
)
PI_OLD_REV=$(npm view "@earendil-works/pi-coding-agent@$PI_OLD_VERSION" gitHead)
PI_TARGET_REV=$(npm view "$PI_TARGET_PACKAGE@$PI_TARGET_VERSION" gitHead)
PI_CHK=$(bash ~/.pi/agent/skills/librarian/checkout.sh \
  github.com/earendil-works/pi --force-update --path-only)
git -C "$PI_CHK" cat-file -e "$PI_LAZY_OLD_REV^{commit}"
git -C "$PI_CHK" cat-file -e "$PI_LAZY_TARGET_REV^{commit}"
git -C "$PI_CHK" cat-file -e "$PI_OLD_REV^{commit}"
git -C "$PI_CHK" cat-file -e "$PI_TARGET_REV^{commit}"
printf 'runtime=%s\nold=%s\ntarget_package=%s\ntarget_version=%s\ntarget=%s\n' \
  "$PI_OLD_VERSION" "$PI_OLD_REV" "$PI_TARGET_PACKAGE" "$PI_TARGET_VERSION" "$PI_TARGET_REV"
```

For pi-vim, first freeze its independent lazy range:

```bash
VIM_LAZY_OLD_REV='copy pi-vim installed revision from header'
VIM_LAZY_TARGET_REV='copy pi-vim target revision from header'
```

Then resolve the package actually loaded by `prompt-editor`:

```bash
set -euo pipefail
VIM_OLD_VERSION=$(node -p 'require(process.env.HOME + "/.pi/agent/npm/node_modules/pi-vim/package.json").version')
VIM_TARGET_VERSION=$(npm view pi-vim version)
VIM_OLD_REV=$(npm view "pi-vim@$VIM_OLD_VERSION" gitHead)
VIM_TARGET_REV=$(npm view "pi-vim@$VIM_TARGET_VERSION" gitHead)
VIM_CHK=$(bash ~/.pi/agent/skills/librarian/checkout.sh \
  github.com/lajarre/pi-vim --force-update --path-only)
git -C "$VIM_CHK" cat-file -e "$VIM_LAZY_OLD_REV^{commit}"
git -C "$VIM_CHK" cat-file -e "$VIM_LAZY_TARGET_REV^{commit}"
git -C "$VIM_CHK" cat-file -e "$VIM_OLD_REV^{commit}"
git -C "$VIM_CHK" cat-file -e "$VIM_TARGET_REV^{commit}"
printf 'runtime=%s\nold=%s\ntarget_version=%s\ntarget=%s\n' \
  "$VIM_OLD_VERSION" "$VIM_OLD_REV" "$VIM_TARGET_VERSION" "$VIM_TARGET_REV"
```

A lazy target can contain commits not present in the frozen published release.
Classify that difference explicitly; only the published `gitHead` range describes
the runtime package under compatibility review.

**Complete when:** every applicable lazy and npm range is recorded, every revision
exists locally, and any difference between lazy target and published target is
classified as released or unreleased.

## 2. Review private integration surfaces

Inspect each distinct lazy or published runtime range once.

For Pi, inspect the same private surfaces across both ranges:

```bash
git -C "$PI_CHK" log --oneline "$PI_OLD_REV..$PI_TARGET_REV"
git -C "$PI_CHK" diff --stat "$PI_OLD_REV..$PI_TARGET_REV"
git -C "$PI_CHK" diff "$PI_LAZY_OLD_REV..$PI_LAZY_TARGET_REV" -- \
  packages/tui/src/components/editor.ts \
  packages/coding-agent/src/modes/interactive/components/custom-editor.ts \
  packages/coding-agent/src/core/extensions/types.ts \
  packages/coding-agent/src/modes/interactive/interactive-mode.ts
git -C "$PI_CHK" diff "$PI_OLD_REV..$PI_TARGET_REV" -- \
  packages/tui/src/components/editor.ts \
  packages/coding-agent/src/modes/interactive/components/custom-editor.ts \
  packages/coding-agent/src/core/extensions/types.ts \
  packages/coding-agent/src/modes/interactive/interactive-mode.ts
```

Account for `Editor` state/layout methods, `CustomEditor` behavior, editor factory
signatures, cursor rendering, input dispatch, and every private member accessed
structurally by `prompt-editor`.

For pi-vim, inspect both ranges:

```bash
git -C "$VIM_CHK" log --oneline "$VIM_OLD_REV..$VIM_TARGET_REV"
git -C "$VIM_CHK" diff --stat "$VIM_OLD_REV..$VIM_TARGET_REV"
git -C "$VIM_CHK" diff "$VIM_LAZY_OLD_REV..$VIM_LAZY_TARGET_REV" -- \
  index.ts types.ts visual.ts settings.ts clipboard-policy.ts mode-colors.ts \
  mode-change-command.ts cursor-shape.ts
git -C "$VIM_CHK" diff "$VIM_OLD_REV..$VIM_TARGET_REV" -- \
  index.ts types.ts visual.ts settings.ts clipboard-policy.ts mode-colors.ts \
  mode-change-command.ts cursor-shape.ts
```

Account for `ModalEditor` construction, public setters, modes, pending-input fields,
Ex dispatch, session setup/cleanup, settings, clipboard behavior, colorizers, and
copied or re-exported helpers.

For either upstream, read only the headings in the
[compatibility reference](REFERENCE.md) implicated by its diffs.

**Complete when:** every changed integration surface and every structurally accessed
private member is classified as compatible, requiring a concrete edit, or
intentionally unsupported with a stated reason.

## 3. Finish the review

Report each private integration surface as compatible, requiring a concrete edit,
or intentionally unsupported. Name the static, runtime, and interactive checks that
must run after the target is installed; the current runtime cannot prove target
compatibility.

When the caller explicitly requests installation or source adaptation, continue with
the [apply branch](APPLY.md).

**Complete when:** review-only runs leave prompt-editor source and package
installations untouched and name every required follow-up; apply requests continue
with the exact frozen targets.
