# Permission Gate

An accidental-operation gate for Pi. Local Bash AST rules identify calls that need approval, then Jev decides whether to skip manual confirmation. SQL rules use Jev to identify read-only false positives before asking for confirmation. Write/edit protected paths retain their manual guards. **This is not a security boundary or a comprehensive command-safety checker.**

Pi automatically loads only this directory's `index.ts`, which registers the Bash, Path Guard and SQL Guard handlers. The internal guard files are not separate auto-loaded extensions. Run `/reload` after changes. The extension uses shared libraries and npm dependencies from the agent root; it is not a standalone npm package.

## Commands

| Command               | Purpose                                                                 |
| --------------------- | ----------------------------------------------------------------------- |
| `/gate`               | Show status and usage                                                   |
| `/gate git [on\|off]` | Show or toggle local Git rules                                          |
| `/gate jev [on\|off]` | Show or toggle Jev auto-approval                                        |
| `/gate log`           | Show the latest 20 Jev decision summaries on the current session branch |

Git rules and Jev both default to **ON**. Switches live only in the current extension instance and reset to ON on `/reload`.

- `git off`: Git no longer triggers local approval rules; other matches in the same command still apply.
- `jev off`: Locally matched calls require manual confirmation; it does not disable the local rules.

## Bash decision flow

1. Handle only `bash tool_call`, including nested Bash calls from codemode; ignore other tools and `user_bash`.
2. Inspect the complete syntax tree with the Tree-sitter Bash parser. Unmatched calls proceed without a Jev request.
3. For a matched call, one Jev request evaluates the entire command, including all subcommands, redirections and substitutions:

   ```text
   intent_covered  >= 0.80   Actions and important side effects are authorized
   scope_covered   >= 0.90   Targets and effects stay within the authorized scope
   effects_covered >= 0.90   Material effects are covered by that authorization
   ```

   Auto-approve only when all conditions pass; otherwise ask the user. `effects_covered` is not intrinsic safety: explicitly accepted destructive effects do not automatically prevent approval.

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

## SQL decision flow

1. Match the existing SQL tool suffixes (`_sqlcl_run`, `_sql_run`, `_execute_sql`) and read the first non-empty string in `sql` / `sqlcl`. MCP direct and codemode nested calls use the same handler.
2. Keep existing local SQL rules unchanged. Locally accepted queries proceed without Jev, including their existing detection limits.
3. Only SQL requiring confirmation reaches Jev. One `read_only` question evaluates the complete SQL, including multiple statements, CTEs, procedural blocks and function calls. Auto-approve when `read_only >= 0.90`; otherwise ask the user. Unknown routine semantics, mutations, explicit locks and other non-read-only effects require confirmation. This is **not user-authorization classification**: SQL requests do not include user intent.
4. `/gate jev off` retains manual confirmation for local matches. Missing SQL parameters ask without classification; unsupported argument shapes remain hard-blocked.
5. Failed, oversized or uncertain classifications fall back to the existing confirmation dialog. Session lifecycle and parent-operation cancellation stop old calls without aborting a replacement operation.

SQL uses question version 1; Bash retains authorization questions version 3. The SQL threshold has offline regression coverage but has not been calibrated against a live classifier.

## Jev, context and failure behavior

The extension calls the fixed model `typesafe/jev-latest` through Pi's `ctx.modelRegistry.classify()`. Pi manages authentication, for example through `TYPESAFE_API_KEY`.

Bash requests contain only the full command, the latest ordinary `user` message on the current session branch, and `cwd`. Questions use `cwd` to resolve relative targets, not as authorization. SQL requests contain only the full selected SQL string and concrete tool name, not other tool parameters, database contents or user messages. Rule identifiers stay in dialogs and logs. **Inputs are not redacted.** File contents, tool output and full conversation history are not sent. Command/SQL text may reach the provider even if execution is ultimately rejected.

- Commands and SQL are limited to 8,000 characters and Bash user messages to 16,000. Oversized inputs require manual confirmation rather than truncation-based approval.
- Missing authorization, unavailable models/credentials, request failures, invalid responses and out-of-range probabilities fall back to manual confirmation.
- Each request has one outer five-second deadline and `maxRetries: 0`; no second provider timer. Parent-operation cancellation stops classification/confirmation; late results cannot approve execution.
- **Parser exceptions retain the existing warn-and-allow behavior:** warn when UI is available, then skip checks and allow execution. Syntax errors alone do not require confirmation, but recognized hazards in recovered syntax trees still match.

Authorization is read directly from the latest ordinary `user` entry returned by `getBranch()`, without input fingerprints, provenance handlers or added message metadata. Pi persists template-expanded and transformed text before tool calls, so Jev receives that latest text. Text blocks are joined with newlines; an images-only or empty latest user requires manual confirmation and never falls back to older authorization. Custom messages do not provide user authorization.

**Accepted limit:** ordinary `user` messages cannot distinguish real user input from extension-injected `sendUserMessage` input. Both, as well as legacy ordinary user messages, can supply authorization. Extensions are trusted accordingly; this simplification is not provenance verification. User-entry ID, session ID and cancellation checks still prevent stale decisions from approving calls.

Protected-path checks remain manual and independent of Jev. Neither switch disables SQL/path checks; `/gate jev` controls auto-approval for Bash and SQL, while `/gate git` affects only local Bash Git rules.

## Code and integration

| File                                                 | Responsibility                                                            |
| ---------------------------------------------------- | ------------------------------------------------------------------------- |
| [index.ts](index.ts)                                 | Events, lifecycle, confirmation flow and `/gate` commands                 |
| [policy.ts](policy.ts)                               | Local AST rules and fixed rule labels                                     |
| [jev.ts](jev.ts)                                     | Questions, request deadlines, response validation and threshold decisions |
| [intent.ts](intent.ts)                               | Latest ordinary user entry and text extraction                            |
| [path-guard.ts](path-guard.ts)                       | Manual write/edit protected-path checks                                   |
| [sql-guard.ts](sql-guard.ts)                         | SQL rules, Jev read-only checks and confirmation                           |
| [log.ts](log.ts)                                     | Decision-summary format and log display                                   |
| [../../lib/bash-parser.ts](../../lib/bash-parser.ts) | Shared Bash parser                                                        |
| [confirmation.ts](confirmation.ts)                   | Shared confirmation, notification, cancellation and blocking outcomes     |
| [confirmation-queue.ts](confirmation-queue.ts)       | Confirmation serialization by UI object                                   |

Gate, Path Guard and SQL Guard share `confirm(pi, ctx, title, message)`, which returns only a confirmation outcome. Notifications use the dialog title and message. `confirmationResult(outcome)` converts outcomes to fixed blocking reasons; guards cannot customize those reasons. Bash retains session/intent validity checks locally; SQL uses session validity without user intent. Both pass the shared instance lifecycle and parent-operation signals through `ctx.signal`. All guards share a confirmation queue. Without UI they block; rejection aborts the operation; cancellation cannot approve a call; dialog or notification errors return a blocking result without exposing error details. Gate's classification work is not serialized by this queue. Third-party UI calls do not necessarily participate. Queue scheduling has automated test coverage; the host TUI's dialog-overwrite risk was established by source analysis, not an end-to-end reproduction.

The Bash `command` argument is locked when checks begin. Rewriting it in a later `tool_call` handler fails and Pi blocks execution; extensions that rewrite commands must run before Gate. Other Bash arguments remain mutable. SQL checks similarly lock existing `sql` / `sqlcl` fields; other SQL tool arguments remain mutable.

Decisions are stored as non-model-context entries containing fixed rules, probabilities, model, question version, latency and manual outcomes. SQL entries use the `SQL` rule label and `read_only` probability. Entries do not additionally store raw commands, SQL, user messages or provider error bodies. Logs record approval outcomes, not successful tool execution.

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

Relevant tests are grouped in `tests/permission-gate/`: `bash.test.ts` covers local Bash rules, `index.test.ts` covers integrated decisions and lifecycle, `sdk.test.ts` covers real SDK discovery and input, `path-guard.test.ts` covers manual path checks, `sql-guard.test.ts` covers SQL rules/read-only classification/fallbacks, `../mcp.test.ts` covers real MCP direct and nested dispatch, `confirmation.test.ts` covers common confirmation outcomes, `confirmation-queue.test.ts` covers shared scheduling, and `calibration.test.ts` covers synthetic fixtures and opt-in live calibration. The SDK regression uses the real Pi SDK and repository `prompts/commit.md` to exercise directory discovery, single index registration and latest expanded user text, with offline model/classifier stubs and no executable tools. Ordinary tests do not call a live classifier.

Explicitly enable live calibration:

```bash
GATE_CALIBRATE=1 \
GATE_CALIBRATION_REPORT="${TMPDIR:-/tmp}/permission-gate-calibration.json" \
./node_modules/.bin/vitest run tests/permission-gate/calibration.test.ts
```

Calibration sends only synthetic text from `tests/permission-gate/fixtures.ts`; **it never registers or executes a Bash tool**. The report path is optional. There are 24 matched fixtures, each sampled three times, plus three coverage-exclusion cases, including relative-path probes. Development-time v2 measurements under both the original 0.90 intent threshold and the current 0.80 threshold produced 24 authorized approvals and 42 confirmations for unauthorized or unclear-scope samples in each run. This is a small, development-tuned sample, not independent accuracy evidence. Questions v3 use positive `effects_covered` wording; the historical v2 results do not validate v3. Recalibrate after changing questions, model or context.

Following fx’s task-focused state, Gate sends only fields used by its questions. It keeps Pi’s direct classifier API and catalog model: no extra backend layer, model override, retries, hedging, credential scanner or usage pipeline. Inputs remain unredacted.

Reference-project links are collected under “LLM or Jev Judge” in [../../TODO.md](../../TODO.md).
