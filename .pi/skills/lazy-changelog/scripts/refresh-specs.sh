#!/usr/bin/env bash
# refresh-specs.sh — regenerate the lazy-changelog specs cache by running
# dump-specs.lua inside Neovim (with your config, so lazy resolves all specs).
#
# Run this (or rely on lazy-changelog.sh's always-refresh) right after
# `:Lazy check`, so the specs cache matches the freshly-fetched origin refs.
#
# Output: $SPEC_FILE (default ~/.cache/lazy-changelog/specs.tsv)
#
# Needs a real Neovim binary; this repo's .pi/sandbox.json allows `nvim` via
# justBash.hostCommands, so it runs inside the agent sandbox too.
#
# NOTE: written for Termux's restricted `bash` — no trap, no process subst.

set -u

SPEC_FILE="${SPEC_FILE:-$HOME/.cache/lazy-changelog/specs.tsv}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_LUA="$SCRIPT_DIR/dump-specs.lua"

# locate nvim: explicit $NVIM, else PATH, else common install paths (Termux,
# bob, Homebrew, system)
nvim="${NVIM:-$(command -v nvim 2>/dev/null)}"
if [ -z "$nvim" ] || [ ! -x "$nvim" ]; then
  for cand in "/data/data/com.termux/files/usr/bin/nvim" "$HOME/.local/share/bob/nvim-bin/nvim" "/opt/homebrew/bin/nvim" "/usr/bin/nvim" "$HOME/.local/bin/nvim"; do
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

# dump-specs.lua writes the TSV straight to $tmp (via lazy.util.write_file)
# when LAZY_CHANGELOG_SPEC_FILE is set, so nvim's own stdout — iTerm2 OSC
# escape sequences, plugin startup chatter, deprecation notices — is discarded
# and can never pollute the data. We only check $tmp for success.
#
# NVIM_LOG_FILE is pinned too: nvim writes ./nvim.log in its cwd by default,
# and this script never cds, so that lands wherever the caller ran from —
# i.e. the repo working tree under lazy-changelog.sh. Point it next to
# $SPEC_FILE (an already-created, writable cache dir) so the log is kept for
# debugging without leaking into the repo.
NVIM_LOG_FILE="$(dirname "$SPEC_FILE")/nvim.log" \
  LAZY_CHANGELOG_SPEC_FILE="$tmp" \
  "$nvim" --headless +"luafile $DUMP_LUA" +qa >/dev/null 2>&1

rc=$?
if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then
  echo "error: nvim headless run failed (exit $rc) or wrote no output." >&2
  echo "       try: LAZY_CHANGELOG_SPEC_FILE=$tmp $nvim --headless +luafile $DUMP_LUA +qa" >&2
  rm -f "$tmp"
  [ "$rc" -ne 0 ] || rc=1
  exit "$rc"
fi

mv "$tmp" "$SPEC_FILE"
echo "wrote $(wc -l < "$SPEC_FILE" | tr -d ' ') plugins to $SPEC_FILE" >&2
