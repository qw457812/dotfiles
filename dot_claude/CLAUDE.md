# Git Commit

Heredocs (`<<EOF`) fail in sandbox. For commits, use literal newlines in `-m`.

Note: multiple `-m` flags add blank lines between each.

```bash
# Correct:
git commit -m "subject

body line 1
body line 2"

# Wrong:
git commit -m "$(cat <<'EOF'...)"
```
