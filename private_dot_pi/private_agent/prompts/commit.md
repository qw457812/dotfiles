---
description: Generate a Conventional Commit message for staged changes
source: https://github.com/telagod/pi-agent-colony/blob/65825ec2ada22b8d1a1a8d03aae3a3394b75d8fd/pi-package/prompts/commit.md
---
Generate a commit message for the current staged changes (`git diff --cached`).

Follow Conventional Commits format:
```
type(scope): description

[optional body]
```

Types: feat, fix, refactor, docs, test, chore, perf, ci, style, build
- Keep the subject line under 72 characters
- Use imperative mood ("add" not "added")
- Body explains WHY, not WHAT (the diff shows what)

$@
