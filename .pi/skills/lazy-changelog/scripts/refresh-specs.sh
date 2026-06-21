#!/usr/bin/env bash
# refresh-specs.sh — regenerate the lazy-changelog specs cache by running
# dump-specs.lua inside Neovim (with your config, so lazy resolves all specs).
#
# Run this (or pass --refresh to lazy-changelog.sh) right after `:Lazy check`,
# so the specs cache matches the freshly-fetched origin refs.
#
# Output: $SPEC_FILE (default ~/.cache/lazy-changelog/specs.tsv)
#
# NOTE: written for Termux's restricted `bash` — no trap, no process subst.

set -u

SPEC_FILE="${SPEC_FILE:-$HOME/.cache/lazy-changelog/specs.tsv}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_LUA="$SCRIPT_DIR/dump-specs.lua"

# locate nvim: explicit $NVIM, else PATH, else common Termux path
nvim="${NVIM:-$(command -v nvim 2>/dev/null)}"
if [ -z "$nvim" ] || [ ! -x "$nvim" ]; then
  for cand in "/data/data/com.termux/files/usr/bin/nvim" "/usr/bin/nvim" "$HOME/.local/bin/nvim"; do
    [ -x "$cand" ] && nvim="$cand" && break
  done
fi

if [ -z "$nvim" ] || [ ! -x "$nvim" ]; then
  echo "error: nvim not found. Set \$NVIM or add it to PATH." >&2
  exit 1
fi
[ -f "$DUMP_LUA" ] || { echo "error: dump-specs.lua missing: $DUMP_LUA" >&2; exit 1; }

mkdir -p "$(dirname "$SPEC_FILE")"
tmp="${SPEC_FILE}.$$"
: > "$tmp"

# headless: load config (lazy resolves specs), run the dump, quit.
"$nvim" --headless \
  +"lua vim.g.skip_ts_auto_install = true" \
  +"luafile $DUMP_LUA" \
  +qa 2>/dev/null > "$tmp"

rc=$?
if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then
  echo "error: nvim headless run failed (exit $rc) or produced no output." >&2
  echo "       try running manually: $nvim --headless +luafile $DUMP_LUA +qa" >&2
  rm -f "$tmp"
  [ "$rc" -ne 0 ] || rc=1
  exit "$rc"
fi

mv "$tmp" "$SPEC_FILE"
echo "wrote $(wc -l < "$SPEC_FILE" | tr -d ' ') plugins to $SPEC_FILE" >&2
