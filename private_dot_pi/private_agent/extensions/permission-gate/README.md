# Permission Gate

A Bash accidental-operation gate for Pi. Local AST rules identify calls that need approval, then Jev decides whether to skip manual confirmation. **This is not a security boundary or a comprehensive command-safety checker.**

Pi automatically loads this directory's `index.ts`. Run `/reload` after changes. The extension uses shared libraries and npm dependencies from the agent root; it is not a standalone npm package.

## Commands

| Command | Purpose |
|---|---|
| `/gate` | Show status and usage |
| `/gate git [on\|off]` | Show or toggle local Git rules |
| `/gate jev [on\|off]` | Show or toggle Jev auto-approval |
| `/gate log` | Show the latest 20 Jev decision summaries on the current session branch |

Git rules and Jev both default to **ON**. Switches live only in the current extension instance and reset to ON on `/reload`.

- `git off`: Git no longer triggers local approval rules; other matches in the same command still apply.
- `jev off`: Locally matched calls require manual confirmation; it does not disable the local rules.

## Decision flow

1. Handle only `bash tool_call`, including nested Bash calls from codemode; ignore other tools and `user_bash`.
2. Inspect the complete syntax tree with the Tree-sitter Bash parser. Unmatched calls proceed without a Jev request.
3. For a matched call, one Jev request evaluates the entire command, including all subcommands, redirections and substitutions:

   ```text
   intent_covered  >= 0.80   Actions and important side effects are authorized
   scope_covered   >= 0.90   Targets and effects stay within the authorized scope
   unexpected_harm <= 0.10   No apparent material effect outside that authorization
   ```

   Auto-approve only when all conditions pass; otherwise ask the user. `unexpected_harm` is not intrinsic danger: explicitly accepted destructive effects do not automatically prevent approval.
4. Every matched operation is eligible for auto-approval. There is no fixed hard-deny list or non-overridable `deny` decision.
5. Manual rejection blocks execution and calls `ctx.abort()`. Calls requiring confirmation are blocked when no UI is available.

### Local rules

- `sudo`, `dd`, and `mkfs`/`mkfs.*`.
- Recursive `chown`/`chgrp`.
- Recursive `rm`, or deletion of literal targets normalized to `/`, `.`, `..`, or a temporary-directory root.
- Recursive `chmod`, or modes matching world-writable/set-ID permissions.
- Git: `add`, `commit`, `push`, `pull`, `merge`, `rebase`, `reset`, `checkout`, `switch`, `stash`, `cherry-pick`, `revert`, `restore`, and `clean`.
- Write redirections to `/dev/*` (including `<>`), except `null`, `stdout`, `stderr`, and `fd/0..2`.

Deletion is exempt when every target is a literal absolute descendant of a recognized temporary directory and only recognized common options precede the targets. Recognized directories include `/tmp`, `/var/tmp`, and the host process's `tmpdir()`, plus `/private/tmp` and `/private/var/tmp` on macOS. Temporary-directory roots themselves are not exempt.

## Jev, context and failure behavior

The extension calls the fixed model `typesafe/jev-latest` through Pi's `ctx.modelRegistry.classify()`. Pi manages authentication, for example through `TYPESAFE_API_KEY`.

Requests contain the full Bash command, the latest attributable real user message on the current branch, `cwd`, and fixed rule identifiers. **Inputs are not redacted.** File contents, tool output and full conversation history are not sent. Command text may reach the provider even if execution is ultimately rejected.

- Commands are limited to 8,000 characters and user messages to 16,000. Oversized inputs require manual confirmation rather than truncation-based approval.
- Missing authorization, unavailable models/credentials, request failures, invalid responses and out-of-range probabilities fall back to manual confirmation.
- Each request has a five-second deadline and `maxRetries: 0`. Parent-operation cancellation stops classification/confirmation; late results cannot approve execution.
- **Parser exceptions retain the existing warn-and-allow behavior:** warn when UI is available, then skip checks and allow execution. Syntax errors alone do not require confirmation, but recognized hazards in recovered syntax trees still match.

Pi's ordinary `user` messages do not preserve input provenance. The extension matches text fingerprints from `input` and `message_end` and persists `permissionGateSource` metadata. For a single non-queued slash input such as `/commit`, `before_agent_start` associates the expanded prompt with that input's original source. This handles template expansion without assuming that the latest input owns every message. Multiple candidates, queued expansions and uncorrelated non-slash transformations remain unknown.

Only attributable `interactive`/`rpc` input can authorize actions. Expanded extension-injected input retains its `extension` source and cannot provide authorization. Legacy messages and ambiguous sources require manual confirmation instead of guessing historical authorization.

## Code and integration

| File | Responsibility |
|---|---|
| [index.ts](index.ts) | Events, lifecycle, confirmation flow and `/gate` commands |
| [policy.ts](policy.ts) | Local AST rules and fixed rule labels |
| [jev.ts](jev.ts) | Questions, request deadlines, response validation and threshold decisions |
| [intent.ts](intent.ts) | Input fingerprints and real user authorization extraction |
| [log.ts](log.ts) | Decision-summary format and log display |
| [../../lib/bash-parser.ts](../../lib/bash-parser.ts) | Shared Bash parser |
| [../../lib/confirmation-queue.ts](../../lib/confirmation-queue.ts) | Confirmation serialization by UI object |

Gate, Safe Guard and SQL Guard share a confirmation queue. Gate's classification work is not serialized by this queue. Third-party UI calls do not necessarily participate. Queue scheduling has automated test coverage; the host TUI's dialog-overwrite risk was established by source analysis, not an end-to-end reproduction.

The Bash `command` argument is locked when checks begin. Rewriting it in a later `tool_call` handler fails and Pi blocks execution; extensions that rewrite commands must run before Gate. Other Bash arguments remain mutable.

Decisions are stored as non-model-context entries containing fixed rules, probabilities, model, question version, latency and manual outcomes. They do not additionally store raw commands, user messages or provider error bodies. Logs record approval outcomes, not successful tool execution.

## Known limits

- Dynamic executable names, aliases and functions are not resolved. Wrappers such as `env`, `command`, `xargs`, shell `-c` and `eval` strings are not unwrapped.
- Variables and globs are not evaluated. Symlinks, filesystem state, Git hooks, remote state and cross-tool interactions are not inspected.
- Tool output is not sent, so the extension cannot reliably track whether an action originated in a malicious page or another prompt injection.
- Pi's permission hook exposes only the parent agent-run signal. For independent nested-call cancellation, Pi prevents execution after the permission hook, but Gate cannot stop that request early and may still log approval.
- Thresholds are not a joint safety probability, and `jev-latest` can drift.

## Tests and calibration

Run from the agent root:

```bash
npm run check
npm run lint
npm test
```

Relevant tests are in `tests/permission-gate.test.ts`, `tests/permission-gate-jev.test.ts`, `tests/permission-gate-template.test.ts`, `tests/confirmation-queue.test.ts`, and `tests/permission-gate-calibration.test.ts`. The template regression uses the real Pi SDK and repository `prompts/commit.md` to exercise expansion and provenance persistence, with offline model/classifier stubs and no executable tools. Ordinary tests do not call a live classifier.

Explicitly enable live calibration:

```bash
GATE_CALIBRATE=1 \
GATE_CALIBRATION_REPORT="${TMPDIR:-/tmp}/permission-gate-calibration.json" \
./node_modules/.bin/vitest run tests/permission-gate-calibration.test.ts
```

Calibration sends only synthetic text from `tests/fixtures/permission-gate.ts`; **it never registers or executes a Bash tool**. The report path is optional. There are 22 matched fixtures, each sampled three times, plus three coverage-exclusion cases. Development-time v2 measurements under both the original 0.90 intent threshold and the current 0.80 threshold produced 24 authorized approvals and 42 confirmations for unauthorized or unclear-scope samples in each run. This is a small, development-tuned sample, not independent accuracy evidence. Recalibrate after changing questions, model or context.

Reference-project links are collected under “LLM or Jev Judge” in [../../TODO.md](../../TODO.md).
