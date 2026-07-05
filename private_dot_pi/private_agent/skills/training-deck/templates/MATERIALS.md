# Materials

If no user-provided materials are selected for Stage 2, write:

> No user-provided materials selected for Stage 2.

## Material Registry

| ID | Path | Type | Source | Use For | Stage 2 | Notes |
|---|---|---|---|---|---|---|
| <material-id> | `materials/<path>` | <screenshot/diagram/doc/data/etc> | <user/generated/etc> | <teaching use> | `<include | exclude>` | <notes> |

## Handoff Mapping

Rows with `Stage 2 = include` are copied to:

```txt
handoff/deck-brief_files/<filename>
```

`DECK_BRIEF.md` should reference included materials by material ID and handoff-relative path.
