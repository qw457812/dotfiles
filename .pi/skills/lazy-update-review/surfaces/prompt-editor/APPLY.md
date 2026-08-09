# Apply prompt-editor compatibility updates

Load this branch only when the caller explicitly requests applying the frozen and
reviewed Pi or pi-vim target. Substitute the recorded values from
[REVIEW.md](REVIEW.md) in the applicable command block.

## 1. Apply frozen targets

For a Pi update, require the release endpoint to still match the frozen package and
version before allowing its lazy build hook to run:

```bash
set -euo pipefail
PI_TARGET_PACKAGE='recorded-pi-package'
PI_TARGET_VERSION='recorded-pi-version'
PI_PACKAGES=(
  @earendil-works/pi-agent-core
  @earendil-works/pi-ai
  @earendil-works/pi-coding-agent
  @earendil-works/pi-tui
)

test "$(curl -fsSL https://pi.dev/api/latest-version | node -e '
  const fs = require("node:fs");
  const value = JSON.parse(fs.readFileSync(0, "utf8"));
  if (value.ok !== true || typeof value.packageName !== "string" || typeof value.version !== "string") {
    throw new Error("invalid Pi release metadata");
  }
  process.stdout.write(`${value.packageName}@${value.version}`);
')" = "$PI_TARGET_PACKAGE@$PI_TARGET_VERSION"
for package in "${PI_PACKAGES[@]}"; do
  test "$(npm view "$package@$PI_TARGET_VERSION" version)" = "$PI_TARGET_VERSION"
done

pi update --self
test "$(pi --version)" = "$PI_TARGET_VERSION"
cd private_dot_pi/private_agent
npm install --save-dev --save-exact \
  "@earendil-works/pi-agent-core@$PI_TARGET_VERSION" \
  "@earendil-works/pi-ai@$PI_TARGET_VERSION" \
  "@earendil-works/pi-coding-agent@$PI_TARGET_VERSION" \
  "@earendil-works/pi-tui@$PI_TARGET_VERSION"
cd -
```

This synchronizes the exact Pi source pins, lockfile, and source `node_modules`.

For a pi-vim update, install the reviewed version exactly and synchronize the source
dependency:

```bash
set -euo pipefail
VIM_TARGET_VERSION='recorded-pi-vim-version'

pi install "npm:pi-vim@$VIM_TARGET_VERSION"
test "$(node -p 'require(process.env.HOME + "/.pi/agent/npm/node_modules/pi-vim/package.json").version')" = \
  "$VIM_TARGET_VERSION"
cd private_dot_pi/private_agent
npm install --save-dev --save-exact "pi-vim@$VIM_TARGET_VERSION"
cd -
```

The exact install temporarily pins Pi's package setting. Restore its chezmoi source
to the rolling `npm:pi-vim` entry after verifying the runtime; future reviews will
freeze the next release before updating. Use `pi install npm:pi-vim@<version>` to
restore another specific managed version.

Regenerate `pi-vim.generated.ts` by loading Pi after changing its template; every
generated re-export must resolve below `getAgentDir()/npm/node_modules/pi-vim`.

**Complete when:** the global runtime, managed pi-vim runtime, source pins, lockfile,
and source `node_modules` are on their intended published versions, and the chezmoi
Pi package setting is restored to its intended rolling source.

## 2. Verify affected branches

After applying the reviewed versions and any required source edits, run:

```bash
cd private_dot_pi/private_agent
npm run check
npm run lint
cd -
pi --list-models >/dev/null
```

Inspect vanilla pi-vim when UI comparison is required:

```bash
pi --no-session --no-extensions -e ~/.pi/agent/npm/node_modules/pi-vim/index.ts
```

Manually exercise every changed interactive branch. For private navigation input,
run every applicable verification case under
[Navigation remaps](REFERENCE.md#navigation-remaps).

**Complete when:** static checks, runtime loading, and every interactive branch
affected by either target range pass.
