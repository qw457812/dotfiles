# Pi target validation

## Isolated target checks

Use for target SDK/behavior checks before apply, or when diagnosing environment failures.

1. **Match the source.** Copy `private_dot_pi/private_agent` under `~/.cache` without `node_modules`; permission fixtures under `os.tmpdir()` are writable by the sandbox and can invalidate read-only assertions. Materialize `dot_gitignore` as `.gitignore` so lint excludes the same files as the deployed tree. Record the source state; recheck affected latest sources if they change during review.
2. **Match dependencies and tools.** Use exact target host packages at the copy root. Enumerate nested manifests and promote dependencies needed by their checks where necessary so nested installs cannot mask target declarations. Preserve unrelated lock/installed resolutions and record disagreements instead of refreshing all caret ranges. Record the actual compiler/linter `.bin` symlink targets and `--version`. Missing native platform packages (e.g. on Termux) are environment blockers. If using a verified compiler fallback, record its version and limits separately from the declared toolchain.
3. **Separate baseline from migration.** Run the unmodified checks and behavioral suite first. Record hardcoded SDK-version assertions and event fixture failures. Make only necessary adaptations in the copy, then rerun and report both results; adaptations are still required source edits. Before comparing source and deployed suites, diff their `tests/**/*.test.ts` inventories with `chezmoi managed`. Preserve unmanaged old tests, report them separately, and rerun the deployed suite excluding only the identified unmanaged files.

**Done when:** each result is tied to a source state, dependency/tool version and test inventory; environment failures and adaptations are separate from runtime regressions.

## Interactive target checks

Use [interactive-testing](../../../../../.agents/skills/interactive-testing/SKILL.md) for fixed-size tmux setup and cleanup. Start the exact target in a temporary `PI_CODING_AGENT_DIR` with copied settings and extensions that generate files; make its reviewed packages available under that directory's `npm/node_modules`. `--no-session` alone only isolates session persistence. Load only the affected extensions (`--no-extensions -e ...`).

For UI-only tests add `--offline` and prefer OS-level network isolation (macOS: `sandbox-exec -p '(version 1)(allow default)(deny network*)'`). `--offline` does not block model calls. If OS isolation is unavailable, use credential-free fixtures, intercept unexpected prompt submissions and reject provider requests; report the weaker isolation. Before sending a slash command, verify the entire editor is empty; Ctrl+U may clear just one line.

- **Prompt-editor:** assert the active instance is `PromptEditor`, not a fallback. Exercise the affected [contracts](../prompt-editor/REFERENCE.md) in regular and fullscreen modes. For cursor/render changes capture raw markers or ANSI, not only pane text. Compare vanilla pi-vim as needed by loading only its `index.ts`.
- **Program status:** with `PI_PROGRAM_STATUS=1`, capture raw OSC 7501 and assert blocked kind/message, hidden overlay behavior where applicable, and recovery on completion/cancellation. Check loaders are not misreported and test reload/session cleanup.
- **Other runtime contracts:** smoke test the affected command owners, extensions, providers or tool routing with the required target settings; report branches or platforms not exercised.

**Done when:** each affected interactive path has target-version evidence or a named blocker, and the test session and temporary state are removed.
