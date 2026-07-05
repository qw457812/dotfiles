# Artifact Contract

## Formal package

Ready workspaces contain:

```txt
training-decks/<deck-slug>/
  README.md
  MISSION.md
  AUDIENCE.md
  KNOWLEDGE.md
  STORYLINE.md
  DELIVERY_PLAN.md
  DECK_BRIEF.md
  RESOURCES.md
  MATERIALS.md
  DECISIONS.md
  OPEN_QUESTIONS.md
  PPT_MASTER_INSTRUCTIONS.md
  STAGE2_HANDOFF.md
  NOTES.md

  reference/
    glossary.md
    concept-map.md
    diagrams.md
    examples.md

  research-notes/
  materials/

  handoff/
    deck-brief.md
    deck-brief_files/
      image_manifest.json
      <included material files>
```

`research-notes/` is scratch. It never enters `handoff/`.

`materials/` is the canonical location for user-provided materials. `handoff/deck-brief_files/` contains only Stage 2 included copies.

## Blocked package

If blocking gaps remain:

```txt
DECK_BRIEF.draft.md
STAGE2_HANDOFF.md  # status: blocked
OPEN_QUESTIONS.md
```

Do not generate `DECK_BRIEF.md` or `handoff/` for a blocked package.

## Status values

`STAGE2_HANDOFF.md` frontmatter uses:

- `ready` — safe to run Stage 2.
- `ready-with-caveats` — safe to run Stage 2, but caveats must be shown and embedded in `DECK_BRIEF.md`.
- `blocked` — do not run Stage 2.

If the user explicitly overrides a blocking gap, record the decision, downgrade the gap to a caveat, and use `ready-with-caveats`.

## Canonical vs handoff

Canonical files:

```txt
DECK_BRIEF.md
RESOURCES.md
MATERIALS.md
PPT_MASTER_INSTRUCTIONS.md
```

Import-safe handoff copy:

```txt
handoff/deck-brief.md
handoff/deck-brief_files/
handoff/resources.md
handoff/materials.md
```

`PPT_MASTER_INSTRUCTIONS.md` is an operation-channel file and must not be copied into `handoff/`.

Stage 2 imports only `deck-brief.md`. `resources.md` and `materials.md` are audit/support files; do not import them by default.

## Frontmatter

Use YAML frontmatter only for:

- `DECK_BRIEF.md`
- `PPT_MASTER_INSTRUCTIONS.md`
- `STAGE2_HANDOFF.md`

Other artifacts are human-readable Markdown without required frontmatter.

## Heading language

Fixed English section headings are required in:

- `DECK_BRIEF.md`
- `PPT_MASTER_INSTRUCTIONS.md`
- `STAGE2_HANDOFF.md`

Content should use the confirmed training language. Other human-facing artifacts may use the training language for headings.

## DECK_BRIEF.md schema

Use the fixed section order:

1. Mission
2. Audience
3. Desired Behavior Change
4. Core Message
5. Locked Decisions
6. Content Priorities
7. Storyline
8. Candidate Slide Inventory
9. Demo / Interaction Plan
10. Definitions / Concept Map
11. Visuals Needed
12. Available Materials
13. Style Brief
14. Anti-goals / Avoid
15. Sources
16. Appendix Candidates
17. Caveats / Non-blocking Open Questions
18. PPT Master Constraints

`DECK_BRIEF.md` must be standalone. A new session should understand the training goal, audience, storyline, constraints, sources, materials, and caveats from this file alone.

## Materials

`MATERIALS.md` is a selection manifest, not a sensitivity workflow.

Only rows with `Stage 2 = include` are copied into `handoff/deck-brief_files/`.

If no materials are selected, still generate:

```txt
handoff/deck-brief_files/image_manifest.json
```

with content:

```json
[]
```

## image_manifest.json

Generate `handoff/deck-brief_files/image_manifest.json` from included material rows. Each item should include at least:

```json
{
  "filename": "example.png",
  "material_id": "example-material-id",
  "type": "screenshot",
  "use_for": "teaching purpose"
}
```

## Artifact Self-check

Before announcing `ready` or `ready-with-caveats`, verify:

- `DECK_BRIEF.md` is standalone.
- All locked decisions are embedded in `DECK_BRIEF.md`.
- Every source ID in `DECK_BRIEF.md` exists in `RESOURCES.md`.
- Every material ID in `DECK_BRIEF.md` exists in `MATERIALS.md`.
- Every `Stage 2 = include` material exists in `handoff/deck-brief_files/`.
- `image_manifest.json` matches included materials; use `[]` when empty.
- No blocking questions remain for `ready` or `ready-with-caveats`.
- `STAGE2_HANDOFF.md` frontmatter points to existing paths.
- `handoff/` contains only import-safe source bundle files.
- `PPT_MASTER_INSTRUCTIONS.md` is not inside `handoff/`.

Fix mechanical failures automatically, then re-check. If a failure requires user judgment, set status to `blocked`, update `OPEN_QUESTIONS.md`, and ask the next blocking question.
