---
name: dsh-plugin
description: Build or change DeepSeek Harness Cordis plugins, including source-loaded direct modules, profile-scoped npm bundles, lifecycle, wiring, tests, installation, and publication.
---

# DSH plugin

Build from the **surface** inward. Direct modules, published bundles, and first-party workspace plugins share Cordis semantics, but their ownership, dependency resolution, and release gates differ.

## Steps

1. **Establish authority and surface.** Read the nearest `AGENTS.md`, the affected profile manifest, the closest working plugin, and the current API package in `~/.local/share/nvim/lazy/deepseek-harness`. Select exactly one surface:
   - **Direct module** — machine-local behavior loaded in place from `dsh-plugins/`; read [`references/direct-plugin.md`](references/direct-plugin.md).
   - **npm bundle** — installable, profile-scoped behavior sourced under `packages/`; read [`references/npm-bundle.md`](references/npm-bundle.md).
   - **First-party workspace plugin** — code inside the DeepSeek Harness checkout; follow its nearest `AGENTS.md`, workspace package conventions, and package-local tests instead of either dotfiles layout.

   Name every profile that should receive the plugin. Ask when distribution or profile scope is ambiguous.

   Completion criterion: one source location, one loading path, and the complete target-profile set are explicit; current API types and a neighboring implementation have been inspected.

2. **Freeze the contract.** Write down what the plugin contributes (service, tool, command, event listener, system-prompt section, or adapter), required and optional services, configuration, ownership of resources, and public package imports. Treat configuration list order as non-semantic; dependencies belong in `inject`.

   Completion criterion: every contribution has an owning registry or effect, every hard dependency is in `inject`, every optional dependency has a use-site fallback, and every external input has a validation policy.

3. **Implement a lifecycle-complete Cordis plugin.** Prefer the function shape and export `name`, optional `inject`, optional runtime `Config`, and `apply`. Use a `Service` subclass only when the plugin provides a service. Use current declaration merges and helpers from the package that owns each surface rather than recreating its types or payloads.

   Registrations made by Cordis-aware APIs unwind with their owner. Acquire unmanaged timers, watchers, processes, sockets, and other resources inside `ctx.effect()` and return their disposer. Keep required services stable through `inject`; probe optional services with `ctx.get()` at the use site. Reject invalid configuration before partial registration.

   Completion criterion: unloading the plugin removes every registration and external resource; dependency loss cannot leave a live consumer holding a dead service; source and generated types agree.

4. **Prove behavior in layers.** Start with pure logic and edge cases, then exercise `apply` against the smallest realistic fake or real registries, including disposer behavior and per-item failure isolation. Validate the loader layer separately from implementation behavior. Use the package's own scripts as the source of truth for check, lint, build, and test commands.

   For a mounted profile, require all applicable evidence:
   - `dsh --profile <profile> --dump-config` contains exactly the intended row and no unintended profile does.
   - `dsh plugin --profile <profile> why <package>` resolves the intended version for npm bundles.
   - A fresh fixed-size tmux session shows the contribution when it affects an interactive UI.

   Completion criterion: every changed surface has a failing-before/passing-after check, the resolved config has the intended cardinality, and interactive behavior is observed when user-visible.

5. **Wire and release through the selected surface.** Keep the requested profile set exact. For a direct module, update its loader patch. For npm, publishing is an external release gate: inspect the tarball, confirm the immutable version is new, publish only with user authorization, then update profile locks from the registry artifact.

   Completion criterion: source module, rendered loader config, and—when applicable—npm registry all identify the same plugin package and version; no profile outside the agreed set loads it.

6. **Close the diff.** Run `git diff --check`, inspect scoped status, remove generated stores, caches, tarballs, and temporary TUI sessions, and preserve unrelated worktree state. Keep portable dependency specifications in tracked manifests; host-absolute paths belong only in transient runtime state.

   Completion criterion: all checks pass, temporary artifacts are gone, related changes have the user's intended staging state, and remaining warnings are either fixed or reported with their owner.

## Current DSH references

Consult the checkout instead of caching API details here:

- `docs/cordis-tutorial/01-first-plugin.md`
- `docs/cordis-tutorial/02-lifecycle-and-effects.md`
- `docs/cordis-tutorial/03-services.md`
- `docs/cordis-tutorial/05-config.md`
- `docs/cordis-tutorial/07-into-the-harness.md`
- `docs/user/develop/basic/publish.md`
- `docs/subsystems/` for generated service, event, and injection surfaces
