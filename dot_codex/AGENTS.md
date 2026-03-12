## Git

- For Git commands matched by `~/.codex/rules/default.rules`, skip the sandboxed first attempt and request `require_escalated` for the initial run, because these state-changing commands typically need to write under `.git` and can fail in the sandbox.
