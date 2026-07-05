---
name: training-deck
description: Prepare a cold-start handoff package for a training deck, then optionally hand off to ppt-master.
disable-model-invocation: true
argument-hint: "Training topic, existing workspace, or STAGE2_HANDOFF.md"
---

# Training Deck

Prepare a high-quality training deck brief before presentation generation. This skill is user-invoked and has two stages:

- **Stage 1 — preparation**: strict grilling, research, candidate mapping, vision lock, artifact synthesis, and a cold-start handoff package.
- **Stage 2 — generation**: only when explicitly requested, hand off to `ppt-master` using the prepared source bundle.

Stage 1 does not depend on other skills. Stage 2 depends on `ppt-master`.

## Route selection

Choose exactly one route before doing work:

1. **new-prep** — the user provides a training topic, rough idea, or requirements.
2. **inspect-existing** — the user points to an existing `training-decks/<deck-slug>/` workspace.
3. **run-stage2** — the user points to `STAGE2_HANDOFF.md` or explicitly says to continue/generate from a handoff.

If the route is ambiguous, ask one strict-grilling question with your recommended route.

## Always follow strict grilling

Before asking questions, inspect available files or artifacts. Do not ask questions answerable from the workspace, source materials, or research.

During discovery and core-lock phases:

- Ask one question at a time.
- Include your recommended/default answer.
- Ask only questions that affect mission, audience, storyline, delivery, content scope, examples, visual intent, or handoff readiness.
- Stop and wait for the user's answer after each question.

Read [`references/grilling-protocol.md`](references/grilling-protocol.md) when entering any user-questioning phase.

## Stage 1 discipline

During grilling and research:

- Do not write formal artifacts such as `MISSION.md`, `DECK_BRIEF.md`, or `STAGE2_HANDOFF.md`.
- Do not create `handoff/`.
- Do not invoke `ppt-master`.
- You may create/update only scratch-safe workspace files: `README.md`, `NOTES.md`, `RESOURCES.md`, and `research-notes/*`.

Formal artifacts are generated together only after the Vision Lock Gate.

## Route A: new-prep

Read these references before executing the route:

- [`references/pipeline.md`](references/pipeline.md)
- [`references/research-policy.md`](references/research-policy.md)
- [`references/artifact-contract.md`](references/artifact-contract.md)

Workflow:

1. Propose a workspace path: `training-decks/<deck-slug>/`; ask for confirmation.
2. Create the workspace after slug confirmation. Early files are scratch only.
3. Run **Core Seed**: collect `Must-cover`, `Candidate`, `Out-of-scope`, and `Unknown` from the trainer.
4. Research from Core Seed + Audience Need + high-trust baseline.
5. Produce a Candidate Map summary: `core`, `supporting`, `optional`, `out`, `gap`, `user-context`.
6. Elicit user examples using research-inspired example prompts.
7. Run Core Lock grilling for blocking gaps and key candidates.
8. Present a Vision Lock Proposal and wait for explicit confirmation.
9. Generate the formal artifact package in one pass using the templates in [`templates/`](templates/).
10. Run the Artifact Self-check from [`references/artifact-contract.md`](references/artifact-contract.md).
11. Stop by default. Show the Stage 2 prompt. Do not enter `ppt-master` unless the user explicitly asks to continue now.

## Route B: inspect-existing

Read the workspace's `README.md`, `STAGE2_HANDOFF.md` if present, and `OPEN_QUESTIONS.md` if present.

- If `status` is `ready` or `ready-with-caveats`, summarize readiness and show the Stage 2 prompt.
- If `status` is `blocked`, summarize blocking questions and continue strict grilling.
- If no handoff exists, treat the workspace as an incomplete Stage 1 prep and continue from the latest available scratch/formal artifacts.

## Route C: run-stage2

Read [`references/ppt-master-handoff.md`](references/ppt-master-handoff.md), then execute that contract.

Minimum behavior:

1. Read `STAGE2_HANDOFF.md`.
2. If `status: blocked`, hard stop; summarize `OPEN_QUESTIONS.md`; ask the next blocking question.
3. If `status: ready` or `ready-with-caveats`, read `PPT_MASTER_INSTRUCTIONS.md`.
4. Create a fresh `.stage2-import/<timestamp>/` containing only:
   - `deck-brief.md`
   - `deck-brief_files/`
5. Invoke `ppt-master` and pass only `.stage2-import/<timestamp>/deck-brief.md` as the source file.
6. Preserve `ppt-master`'s own Strategist confirmation gate. Stage 1 constraints prefill and constrain it; they do not replace it.

## Completion

For Stage 1 completion, report:

- workspace path
- handoff status
- caveats, if any
- exact copy-paste Stage 2 prompt

For Stage 2, follow `ppt-master` until its own workflow stops or completes.
