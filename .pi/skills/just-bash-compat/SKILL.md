---
name: just-bash-compat
description: Adapt Bash scripts for just-bash compatibility. Use when a script must run inside just-bash, behaves differently from native Bash, or needs a just-bash shell-semantics regression test.
disable-model-invocation: true
---

# just-bash compatibility

Use a **differential** loop: native Bash is the semantic baseline, while the
project's real just-bash integration is the compatibility target.

## Steps

1. **Make the mismatch red.** Identify the installed and locked just-bash
   version, then run the unchanged script with the same arguments under native
   Bash and the project's actual just-bash integration. Capture stdout, stderr,
   and exit status from both. Exercise the integration's real filesystem,
   custom commands, environment, and `Bash` options; a bare `new Bash()` misses
   integration-specific behavior when those differ.

   Completion criterion: a deterministic reproducer passes under native Bash
   and fails under the exact just-bash path the project uses, or proves the bug
   is outside just-bash.

2. **Minimize the boundary.** Reduce the reproducer to the smallest construct
   that still differs. Classify it as parser/expansion behavior, `set -e`
   control flow, script argument passing, built-in command behavior, or project
   integration. For those classes, consult
   [known compatibility boundaries](references/known-boundaries.md) and probe
   the installed version before relying on an existing workaround.

   Completion criterion: one minimal probe identifies the failing boundary and
   its observed behavior on the installed version.

3. **Preserve semantics.** Edit the canonical source script and keep
   native Bash behavior intact. Replace only the unsupported boundary. Preserve
   success output, expected no-result behavior, and genuine failure propagation.
   When just-bash cannot represent an interface, provide a compact supported
   form, document it as the preferred form, and make the unsupported form fail
   loudly rather than silently dropping data.

   Completion criterion: the minimized probe is green in both runtimes, with
   every expected failure retaining a non-zero result.

4. **Verify the script as users invoke it.** Re-run the complete script under
   native Bash and the real just-bash integration. Cover successful output,
   expected empty/no-server/no-match behavior, unexpected command failure, and
   every documented argument form affected by the change. Verify generated or
   deployed copies only as outputs; keep edits in the canonical source.

   Completion criterion: every affected branch has matching intended semantics
   in both runtimes, checks for the owning project pass, and temporary sessions,
   sockets, files, and probes are removed.
