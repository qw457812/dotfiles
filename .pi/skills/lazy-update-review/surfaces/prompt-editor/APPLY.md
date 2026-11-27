# Apply reviewed Pi or pi-vim changes

Work only on the caller-authorized installations and source changes. Use the exact package versions and checkout hashes from [the review](REVIEW.md#1-freeze-the-ranges).

## 1. Verify the installed result

Compare current lazy HEAD and loaded runtime versions with the recorded old and target values. An already installed target needs no second installation. A revision/version matching neither recorded endpoint needs a fresh exact-range review.

- **Pi installation:** if still on the reviewed old version, re-read the self-update endpoint and require its package and version to match the frozen target before running the lazy build's `pi update --self`. Verify `pi --version` afterward. Do not accept endpoint drift or a different installed result.
- **pi-vim installation:** use `pi install "npm:pi-vim@<frozen-version>"` and verify the version under the active agent directory's `npm/node_modules/pi-vim`. Exact installation changes Pi's settings entry: after verification restore the intended rolling `npm:pi-vim` in `symlinks/pi/agent/settings.json`, preserving unrelated settings.

**Done when:** the runtime versions used for adaptation match the reviewed target combination, including any peer held at its old version.

## 2. Synchronize authorized edits

- **SDK and pi-vim pins:** enumerate `package.json` files under `private_dot_pi/private_agent`. For every affected root or nested manifest, update the existing pins to the exact reviewed npm versions, preserve their dependency sections, and sync lockfiles and source installs. Inspect unrelated transitive changes. Apply only the source and test adaptations identified by review.
- **Deployment:** verify the affected chezmoi targets; scope any manual apply to changed managed files (including lockfiles written by npm). Source and deployed `node_modules` are separate. Compare resolved versions in both trees and, after deploying locks, refresh stale deployed packages with `npm --prefix <deployed-package-dir> ci --ignore-scripts`; check native dependencies that need lifecycle scripts separately. Record actual `.bin` targets and tool versions **before** reinstalling. Restore only a verified baseline compiler fallback if reinstall erases it; otherwise report the blocker.
- **Generated wrapper:** when the pi-vim runtime or template changes, regenerate by loading Pi in the intended agent directory. Check every wrapper export resolves into that agent directory's managed pi-vim. Finish dependency mutations in both trees before checking either: source checks can import deployed packages through the wrapper.
- **Settings clean filter:** if review identified machine-local keys, update the chezmoi filter template and render/run it to update the active Git filter. Verify idempotence and shareable-key retention without discarding working runtime state.

**Done when:** every affected source/deployed manifest, lockfile and resolved dependency is accounted for and the generated wrapper and package setting point where intended.

## 3. Verify

Run the Pi agent's `check`, `lint` and `test` scripts from `private_dot_pi/private_agent`; use `pi --list-models` as a startup smoke test. Run [interactive target checks](../pi-runtime/VALIDATE.md#interactive-target-checks) for affected UI/command paths. Use the [target validation safeguards](../pi-runtime/VALIDATE.md#isolated-target-checks) when classifying toolchain or dependency problems.

**Done when:** static checks, the behavioral suite, runtime loading and affected interactive paths have passed on the target or are explicitly reported as blocked/untested. Tell the user to restart existing Pi processes; the running host does not reload just because the executable changed.
