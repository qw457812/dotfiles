# Training Deck Pipeline

## Workspace

Default prep workspace:

```txt
training-decks/<deck-slug>/
```

Confirm the slug before creating the workspace. If the user gives an explicit path, use it.

Create the workspace early, but write only scratch-safe files until Vision Lock:

```txt
README.md
NOTES.md
RESOURCES.md
research-notes/
materials/
```

## Stage 1: preparation

### 1. Intake + slug confirmation

Confirm:

- workspace path / slug
- training language
- duration
- delivery setting: `presentation`, `workshop`, `onboarding`, or a primary mixed setting

Use strict grilling; ask one question at a time.

### 2. Core Seed

Ask the trainer for the initial training payload using four buckets:

- `Must-cover` — training fails without it.
- `Candidate` — potentially useful; decide after research.
- `Out-of-scope` — explicitly excluded.
- `Unknown` — the trainer is unsure or wants research to assess.

Do not demand a final thesis yet. Core Seed only directs research.

### 3. Initial Research

Research from Core Seed + Audience Need + high-trust baseline. Update `RESOURCES.md` and optional `research-notes/*`.

### 4. Candidate Map

Before Core Lock, present a Candidate Map summary:

```md
## Candidate Map

### Core
### Supporting
### Optional / Appendix
### Out of Scope
### Gaps
### User-context
```

Use these statuses:

- `core` — belongs in the main storyline.
- `supporting` — background or explanation material.
- `optional` — appendix, speaker notes, or Q&A.
- `out` — excluded.
- `gap` — needs source or user judgment.
- `user-context` — trainer experience/internal practice.

Split `gap` into blocking and non-blocking.

### 5. Example Elicitation

Use research-inspired patterns to ask for user-confirmed examples. Prioritize real or generalized trainer work scenarios.

Examples can support slides, demos, speaker notes, or Q&A.

### 6. Core Lock Grilling

Resolve:

- every blocking gap;
- every key candidate that could enter the main storyline;
- conflicts between user-context and researched knowledge;
- whether examples/materials are included.

Do not confirm every minor item one by one. Batch only obvious background/appendix items in summaries; ask one strict-grilling question for each blocking or key decision.

### 7. Vision Lock Gate

Before writing formal artifacts, present a concise proposal and wait for explicit confirmation:

```md
## Vision Lock Proposal
- Training mission
- Trainer thesis / core payload
- Desired behavior change
- Audience assumptions
- Core narrative
- Must-cover topics
- Supporting / optional topics
- Anti-goals
- Delivery format / duration
- Demo / interaction plan
- Research confidence / source gaps
- User-context framing and caveats
```

Do not write formal artifacts until the user confirms Vision Lock.

### 8. Artifact Synthesis

After Vision Lock, generate the formal artifact package in one pass using `templates/` and the artifact contract.

If blocking gaps remain, generate a blocked package instead of a usable handoff.

### 9. Self-check

Run the Artifact Self-check from `references/artifact-contract.md`. Fix mechanical issues automatically and repeat the check. If a remaining issue requires user judgment, set status to `blocked` and ask the next blocking question.

### 10. Stage 1 complete

Default stop. Show the copy-paste Stage 2 prompt from `STAGE2_HANDOFF.md`.

Only continue into `ppt-master` if the user explicitly asks to generate now.

## Stage 2: generation

Stage 2 is run by the `run-stage2` route. It uses `ppt-master` and the handoff contract. Stage 1 never pre-creates a `ppt-master` project.
