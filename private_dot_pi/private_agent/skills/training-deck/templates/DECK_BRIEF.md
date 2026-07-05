---
deck_slug: "<deck-slug>"
status: "<ready | ready-with-caveats>"
language: "<training language>"
slide_language: "<slide language>"
speaker_notes_language: "<speaker notes language>"
duration: "<duration>"
delivery_setting: "<presentation | workshop | onboarding | mixed>"
recommended_page_range: "<range>"
created_at: "<YYYY-MM-DD>"
---

# Deck Brief

## 1. Mission

<Standalone summary of why this training exists.>

## 2. Audience

<Audience summary, including role segments and assumptions.>

## 3. Desired Behavior Change

After this training, the audience should be able to:

- <observable behavior>

## 4. Core Message

<The one-sentence message the deck should make memorable.>

## 5. Locked Decisions

| Decision | Locked value | Why it matters |
|---|---|---|
| <decision> | <value> | <rationale> |

## 6. Content Priorities

| Topic | Status | Teaching role | Source IDs / Context |
|---|---|---|---|
| <topic> | `<core | supporting | optional | out | user-context>` | <role> | <source/context> |

## 7. Storyline

| Section | Purpose | Key message | Approx. time |
|---|---|---|---:|
| <section> | <purpose> | <message> | <minutes> |

## 8. Candidate Slide Inventory

| Status | Slide intent | Teaching purpose | On-slide content | Speaker-note emphasis | Visual IDs | Source IDs / Context |
|---|---|---|---|---|---|---|
| `<core/supporting/optional>` | <intent> | <purpose> | <concise slide content> | <notes content> | <visual-id> | <source-id/context> |

## 9. Demo / Interaction Plan

| Item | Type | Purpose | Placement | Speaker-note cue |
|---|---|---|---|---|
| <demo/prompt> | `<demo | interaction | exercise | Q&A>` | <purpose> | <where> | <cue> |

## 10. Definitions / Concept Map

| Term / distinction | Working explanation | Why audience needs it | Source IDs / Context |
|---|---|---|---|
| <term> | <explanation> | <reason> | <source/context> |

## 11. Visuals Needed

| Visual ID | Type | Acquire preference | Teaching purpose | Must include | Must avoid | Source IDs / Context |
|---|---|---|---|---|---|---|
| <visual-id> | <conceptual diagram/etc> | `<draw-as-svg | use-material | ai-image | web-image | none>` | <purpose> | <must include> | <must avoid> | <source/context> |

## 12. Available Materials

| Material ID | Relative path | Type | Use for | Suggested placement |
|---|---|---|---|---|
| <material-id> | `deck-brief_files/<file>` | <type> | <use> | <placement> |

If none: `No user-provided materials selected for Stage 2.`

## 13. Style Brief

The deck should be high-level and concise:

- Prefer mental models over exhaustive detail.
- Put nuance in speaker notes.
- Use examples to make concepts concrete.
- Avoid implementation deep dives unless they explain capability or boundary.
- Let `ppt-master` decide the detailed visual system.

Additional style constraints:

- <constraint>

## 14. Anti-goals / Avoid

- <what the deck must avoid>

## 15. Sources

### External / Published Sources

- `<source-id>` — <what it supports>

### User Context

- <trainer experience / internal practice and how to frame it>

### Materials

- `<material-id>` — <what it supports>

## 16. Appendix Candidates

| Topic | Why appendix | Source / Context | Use in Q&A? |
|---|---|---|---|
| <topic> | <reason> | <source/context> | <yes/no> |

## 17. Caveats / Non-blocking Open Questions

| Caveat / question | Impact | How ppt-master should handle |
|---|---|---|
| <caveat> | <impact> | <wording/notes/Q&A handling> |

If status is `ready`, write: `No non-blocking caveats that affect deck generation.`

## 18. PPT Master Constraints

### Locked

- Mission
- Audience assumptions
- Desired behavior changes
- Must-cover concepts
- Anti-goals
- Source boundaries

### Recommended

- Page range
- Section order
- Demo placement
- Style brief
- Candidate slide inventory

### Flexible

- Exact page count
- Visual design system
- Layout choices
- Speaker note wording

### Speaker Notes

Generate speaker notes as a training script:

- Explain the teaching purpose of each slide.
- Include transitions between concepts.
- Include demo cues and interaction prompts.
- Keep on-slide text concise; put nuance in notes.
- Preserve caveats and source boundaries.
