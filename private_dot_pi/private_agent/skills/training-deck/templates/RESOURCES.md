# Resources

Use stable slug IDs. Do not use positional IDs like `R1`.

## Source Registry

| ID | Trust Tier | Type | Title | URL / Path | Use For | Notes |
|---|---|---|---|---|---|---|
| <stable-source-id> | `<official | first-party | source-repo | practitioner | user-context>` | <docs/article/repo/etc> | <title> | <url/path> | <definitions/mechanisms/examples/etc> | <notes> |

## Source Gaps

| Gap | Blocking? | Impact | Plan |
|---|---|---|---|
| <gap> | `<yes/no>` | <impact> | <resolve/downgrade/caveat> |

## Source ID Rules

- IDs are lowercase slugs.
- IDs must remain stable if the table is reordered.
- Every external fact in `DECK_BRIEF.md` must cite an ID from this registry.
- User-context may be listed here only as context, not as external proof.
