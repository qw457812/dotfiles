# Known just-bash compatibility boundaries

These version-scoped diagnostic leads were observed with just-bash 3.1.0.
Probe the installed version before adapting code.

## Process substitution

`< <(...)` is not executable and may fail with `Expected redirection target`.
If buffering is semantically acceptable, capture first and feed a here-string:

```bash
parsed="$(produce_rows)" || exit $?

while IFS= read -r row; do
  consume "$row"
done <<< "$parsed"
```

Command substitution removes trailing newlines and buffering changes streaming
behavior. Account for those differences before using this adaptation.

## Built-in `grep` option termination

The built-in `grep` does not accept GNU's standalone `--`. Use an option that
explicitly consumes the pattern:

```bash
printf '%s\n' "$text" | grep "$grep_flag" -e "$pattern"
```

Include patterns beginning with `-` in the regression test.

## Script argument ceiling

Direct script execution may preserve only the first nine positional arguments;
later arguments can surface as empty values after repeated `shift`. The script
cannot recover values that never reached `$@`.

Keep feature-complete invocations below the ceiling with compact forms such as
`--timeout=10` or `-T10`. Continue supporting ordinary split forms for native
Bash and short invocations. Detect a truncated empty tail and fail with an
explicit compact-form instruction instead of accepting defaults silently. Test
the exact documented full invocation through just-bash as well as each option
in isolation.

## `set -e` and function status propagation

just-bash may apply errexit before a caller can inspect a nested function's
non-zero return. Assignment-only status capture in an `else` branch can also
retain the failed status and exit early.

Put the failing function inside a conditional at each required boundary. For an
expected non-zero state used during a best-effort scan, normalize it before it
crosses the vulnerable function boundary and expose the semantic state
separately:

```bash
item_found=false
run_optional() {
  local status
  item_found=false

  if inspect_item "$@"; then
    item_found=true
    return 0
  else
    status=$?
  fi

  if (( status == EXPECTED_ABSENT )); then
    return 0
  fi
  return "$status"
}
```

The caller checks `item_found` after success. Unexpected failures remain
non-zero. For a required operation, a thin wrapper may translate the expected
status to a user-facing error and return `1`, provided the wrapper itself is
called in a conditional context.

Test this behavior through the complete script. A minimized inline snippet can
pass while script execution, nested functions, or the project's custom command
adapter still fails.
