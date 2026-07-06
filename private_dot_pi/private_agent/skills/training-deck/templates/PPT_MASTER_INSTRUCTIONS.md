---
handoff_version: 1
stage2_mode: "ppt-master"
primary_source: "handoff/deck-brief.md"
operation_channel: true
import_as_deck_content: false
---

# PPT Master Instructions

This file is for the Stage 2 agent. Do not import this file into `ppt-master` as deck content.

## Stage 2 Goal

Generate the training PPT from the prepared brief using `ppt-master`.

## Required Inputs

- Primary source: `handoff/deck-brief.md`
- Companion assets: `handoff/deck-brief_files/`
- Audit only: `RESOURCES.md`, `MATERIALS.md`, `DECISIONS.md`, `OPEN_QUESTIONS.md`

## Import Rule

Create `.stage2-import/<timestamp>/` with only:

```txt
deck-brief.md
deck-brief_files/
```

Invoke `ppt-master` with only:

```txt
.stage2-import/<timestamp>/deck-brief.md
```

Do not pass a directory. Do not import `resources.md`, `materials.md`, this file, or the entire prep workspace by default.

## Respect Stage 1

- Treat `DECK_BRIEF.md` locked constraints as binding unless the user explicitly overrides them in Stage 2.
- Preserve the locked main-deck slide count, slide order, and slide intent from `DECK_BRIEF.md`.
- Do not merge, split, drop, or reorder locked slides unless the user explicitly overrides this in Stage 2.
- Treat recommended constraints as defaults for `ppt-master` Strategist.
- Let `ppt-master` decide flexible visual/layout details.
- Preserve `ppt-master`'s Strategist confirmation gate.

## Research Boundary

Do not re-research by default. Research only if the brief marks a source gap, the user asks, or an obvious factual conflict appears.

## Speaker Notes

Ask `ppt-master` to generate speaker notes as a training script: transitions, teaching purpose, demo cues, interaction prompts, caveats, and source boundaries.
