# Apply prompt-editor compatibility updates

Load this branch only when the caller explicitly requests applying the frozen and
reviewed Pi or pi-vim target. Substitute the recorded values from
[REVIEW.md](REVIEW.md) in the applicable command block.

## 1. Apply frozen targets

First compare `pi --version` and the lazy checkout's HEAD with the recorded review.
If the user already installed the frozen target, skip self-update and continue with
source adaptation; the release endpoint may have advanced since review. A different,
unreviewed installed version/revision requires a new exact-range review.

When Pi is still on the reviewed old version, require the release endpoint to match
the frozen package and version before invoking the lazy build hook's command:

```bash
set -euo pipefail
PI_OLD_VERSION='recorded-old-pi-version'
PI_TARGET_PACKAGE='recorded-pi-package'
PI_TARGET_VERSION='recorded-pi-version'
PI_PACKAGES=(
  @earendil-works/pi-agent-core
  @earendil-works/pi-ai
  @earendil-works/pi-coding-agent
  @earendil-works/pi-tui
)

PI_CURRENT_VERSION=$(pi --version)
if [ "$PI_CURRENT_VERSION" != "$PI_TARGET_VERSION" ]; then
  test "$PI_CURRENT_VERSION" = "$PI_OLD_VERSION"
  test "$(curl -fsSL https://pi.dev/api/latest-version | node -e '
    const fs = require("node:fs");
    const value = JSON.parse(fs.readFileSync(0, "utf8"));
    if (value.ok !== true || typeof value.packageName !== "string" || typeof value.version !== "string") {
      throw new Error("invalid Pi release metadata");
    }
    process.stdout.write(`${value.packageName}@${value.version}`);
  ')" = "$PI_TARGET_PACKAGE@$PI_TARGET_VERSION"
  pi update --self
fi
test "$(pi --version)" = "$PI_TARGET_VERSION"
for package in "${PI_PACKAGES[@]}"; do
  test "$(npm view "$package@$PI_TARGET_VERSION" version)" = "$PI_TARGET_VERSION"
done
cd private_dot_pi/private_agent
npm install --save-dev --save-exact \
  "@earendil-works/pi-agent-core@$PI_TARGET_VERSION" \
  "@earendil-works/pi-ai@$PI_TARGET_VERSION" \
  "@earendil-works/pi-coding-agent@$PI_TARGET_VERSION" \
  "@earendil-works/pi-tui@$PI_TARGET_VERSION"
cd -
```

Repeat the exact-pin update for Pi host dependencies already declared in every
nested extension manifest, not just the root:

```bash
rg --files private_dot_pi/private_agent -g package.json
rg -n '"@earendil-works/pi-' private_dot_pi/private_agent --glob package.json
```

Synchronize each affected manifest, lockfile, and source `node_modules`; verify
installed versions from each package directory. Inspect unrelated transitive
version changes rather than attributing all lockfile churn to Pi. Include the
review's required source and test edits, such as discriminated event fixtures and
old-version assertions. Use the [runtime review's validation safeguards](../pi-runtime/REVIEW.md#2-inspect-changed-integration-contracts)
for dependency and native-toolchain failures.

Deploy changed source paths through chezmoi. Edits normally auto-apply, but lockfiles
written by npm may need a scoped manual apply; verify the relevant deployed files
without deploying unrelated work. Source and deployed `node_modules` are separate:
chezmoi excludes them, so matching manifests do not prove the deployed dependencies
are current. For the root and each affected nested package, compare installed host
versions in both trees. After deploying the locks, synchronize stale deployed
installs with `npm --prefix <deployed-package-dir> ci --ignore-scripts`; verify native
runtime dependencies separately when they require lifecycle scripts.

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

**Complete when:** applicable global/managed runtimes and all affected root/nested
host pins, lockfiles, and source installs match the reviewed versions, deployed
files are current, and the Pi package setting retains its intended rolling source.

## 2. Verify affected branches

After applying the reviewed versions and any required source edits, run:

```bash
cd private_dot_pi/private_agent
npm run check
npm run lint
npm test
cd -
pi --list-models >/dev/null
```

Inspect vanilla pi-vim when UI comparison is required:

```bash
pi --no-session --no-extensions -e ~/.pi/agent/npm/node_modules/pi-vim/index.ts
```

Exercise affected UI in regular and fullscreen modes in a fresh fixed-size tmux
session with a unique socket. Use a temporary `PI_CODING_AGENT_DIR` with copied settings, not symlinks to writable
global settings; `--no-session` only isolates session persistence. Make the reviewed
pi-vim package available below its `npm/node_modules`, and copy extensions that
generate sibling files so probes cannot rewrite deployed wrappers. Load only the
needed extensions with `--no-extensions -e ...` and use `--offline` for UI-only tests.
`--offline` suppresses startup networking, not model requests: block network access
at the OS level for probes that must never submit a request (on macOS, wrap Pi in
`sandbox-exec -p '(version 1)(allow default)(deny network*)'`). Before entering a
slash command, verify the entire editor buffer is empty; Ctrl+U may clear only the
current line of a multiline prompt.
Check that the active instance is `PromptEditor`, not a fallback editor.

Follow [Cursor ownership](REFERENCE.md#cursor-ownership) and
[Navigation remaps](REFERENCE.md#navigation-remaps) when those surfaces change.
Assert raw cursor markers or ANSI output as well as captured screen text; visually
identical frames can hide a broken escape-sequence contract. Clean up the test session.

**Complete when:** static checks, the full behavioral suite, runtime loading, and
every affected interactive branch pass, with compiler fallbacks and untested cases
reported explicitly. Remind the user to restart existing Pi processes: updating
the executable on disk does not reload a running host.
