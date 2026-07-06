# PPT Master Handoff

This contract is used only by the `run-stage2` route.

## Status gate

Read `STAGE2_HANDOFF.md` first.

- `status: blocked` — hard stop. Do not invoke `ppt-master`. Summarize `OPEN_QUESTIONS.md` and ask the next blocking question.
- `status: ready` — proceed.
- `status: ready-with-caveats` — summarize caveats before proceeding, then proceed.

## Operation channel

Read `PPT_MASTER_INSTRUCTIONS.md`. It controls how the Stage 2 agent runs `ppt-master`.

Do not import `PPT_MASTER_INSTRUCTIONS.md` into the `ppt-master` project. It is not deck content.

## Import bundle

The stable handoff bundle is:

```txt
handoff/
  deck-brief.md
  deck-brief_files/
    image_manifest.json
    <included material files>
  resources.md
  materials.md
```

Only `deck-brief.md` is imported into `ppt-master` by default. `deck-brief_files/` follows it as Markdown companion assets.

Do not import `resources.md` or `materials.md` by default. They are audit/support files. `deck-brief.md` must already contain compressed source and material summaries.

## Temporary import bundle

At run time, create a fresh minimal bundle:

```txt
.stage2-import/<timestamp>/
  deck-brief.md
  deck-brief_files/
    image_manifest.json
    <included material files>
```

Copy from `handoff/` into `.stage2-import/<timestamp>/`.

Pass only this file path to `ppt-master`:

```txt
.stage2-import/<timestamp>/deck-brief.md
```

Never pass `.stage2-import/<timestamp>/` as a directory; directory import can accidentally include non-content files.

## ppt-master project name

Default `ppt-master` project name: `<deck-slug>`.

If `projects/<deck-slug>/` already exists, ask whether to reuse/continue or create a new suffix such as `<deck-slug>-v2`.

## Strategist confirmation

Do not bypass `ppt-master`'s Strategist confirmation gate.

Stage 1 constraints should prefill and constrain defaults:

- locked constraints must be respected unless the user explicitly overrides them in Stage 2;
- locked main-deck slide count, slide order, and slide intent must be preserved;
- `ppt-master` must not merge, split, drop, or reorder locked slides unless the user explicitly overrides this in Stage 2;
- recommended constraints guide defaults but may be refined by `ppt-master`;
- flexible items belong to `ppt-master` design judgment.

## Research boundary

Do not re-research by default in Stage 2.

Research only if:

- `DECK_BRIEF.md` identifies a source gap;
- the user explicitly asks;
- `ppt-master` discovers an obvious factual conflict.

## If ppt-master is unavailable

Stop and tell the user that Stage 2 requires `ppt-master`. Do not attempt to recreate the PPT generation pipeline inside this skill.
