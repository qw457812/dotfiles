---
description: Simplify code for clarity and maintainability — reduce complexity without changing behavior
source: https://github.com/addyosmani/agent-skills/blob/df0af6f87de91e9bc3d569c714afdc49a50cf6d6/commands/code-simplify.toml
---

Invoke the code-simplification skill.

Simplify recently changed code (or the specified scope) while preserving exact behavior:

1. Read AGENTS.md and study project conventions
2. Identify the target code — recent changes unless a broader scope is specified
3. Understand the code's purpose, callers, edge cases, and test coverage before touching it
4. Scan for simplification opportunities:
   - Deep nesting → guard clauses or extracted helpers
   - Long functions → split by responsibility
   - Nested ternaries → if/else or switch
   - Generic names → descriptive names
   - Duplicated logic → shared functions
   - Dead code → remove after confirming
5. Apply each simplification incrementally — run tests after each change
6. Verify all tests pass, the build succeeds, and the diff is clean

If tests fail after a simplification, revert that change and reconsider.

$@
