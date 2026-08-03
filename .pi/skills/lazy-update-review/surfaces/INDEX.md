# Config-surface map

Match changed packages by the repository path printed in the lazy report header.
Follow every matching review branch once; packages without a row stay on the generic
`SKILL.md` path.

| Repository | Local config surface | Review branch |
| --- | --- | --- |
| `github.com/earendil-works/pi` | prompt-editor | [prompt-editor/REVIEW.md](prompt-editor/REVIEW.md) |
| `github.com/lajarre/pi-vim` | prompt-editor | [prompt-editor/REVIEW.md](prompt-editor/REVIEW.md) |

Add a row only when a package needs a repeatable specialized review beyond the
generic config search. Co-locate that surface's files under `surfaces/<name>/` and
create only the review, apply, or reference files it actually needs.

**Complete when:** every changed repository matching a row has followed its review
branch, and each unmatched repository has completed the generic path.
