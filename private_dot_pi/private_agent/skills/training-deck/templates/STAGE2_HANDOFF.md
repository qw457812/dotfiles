---
status: "<ready | ready-with-caveats | blocked>"
workspace: "training-decks/<deck-slug>"
deck_slug: "<deck-slug>"
operation_instructions: "PPT_MASTER_INSTRUCTIONS.md"
import_bundle: "handoff/"
primary_source: "handoff/deck-brief.md"
companion_assets: "handoff/deck-brief_files/"
recommended_ppt_project: "projects/<deck-slug>"
created_at: "<YYYY-MM-DD>"
stage2_prompt: "/skill:training-deck run-stage2 training-decks/<deck-slug>/STAGE2_HANDOFF.md"
---

# Stage 2 Handoff

This file is the cold-start entry for Stage 2. Do not depend on prior chat history.

## Status

`<ready | ready-with-caveats | blocked>`

- If `ready`: run Stage 2.
- If `ready-with-caveats`: show caveats, then run Stage 2.
- If `blocked`: do not invoke `ppt-master`; resolve `OPEN_QUESTIONS.md` first.

## Start Stage 2 Prompt

```txt
/skill:training-deck run-stage2 training-decks/<deck-slug>/STAGE2_HANDOFF.md
```

## Stage 2 Procedure

1. Read this file.
2. Check `status`.
3. If status is `blocked`, stop and ask the next blocking question.
4. If status is `ready` or `ready-with-caveats`, read `PPT_MASTER_INSTRUCTIONS.md`.
5. Create `.stage2-import/<timestamp>/` from `handoff/deck-brief.md` and `handoff/deck-brief_files/` only.
6. Invoke `ppt-master` with `.stage2-import/<timestamp>/deck-brief.md` as the source.
7. Preserve `ppt-master`'s Strategist confirmation gate.

## Caveats

<List caveats here if status is `ready-with-caveats`; otherwise write `None`.>

## Key Files

- `DECK_BRIEF.md` — canonical brief.
- `handoff/deck-brief.md` — import-safe source copy.
- `PPT_MASTER_INSTRUCTIONS.md` — operation instructions; do not import as content.
- `OPEN_QUESTIONS.md` — unresolved gaps.
