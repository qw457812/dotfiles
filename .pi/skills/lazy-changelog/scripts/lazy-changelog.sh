#!/usr/bin/env bash
# lazy-changelog.sh — report pending changelogs for lazy.nvim plugins that are
# behind their update target, matching :Lazy check's "Updates" exactly.
#
# It reads the specs cache (from dump-specs.lua), which already contains, per
# plugin, lazy's OWN computed (installed, target) commits — using lazy's
# Git.info / Git.get_target, so version="*", commit=, tag=, pin, disabled,
# local plugins, and the defaults.version fallback are all handled by lazy.
#
# For each plugin where installed != target, it prints `git log installed..target`
# (exactly lazy's log task range). Everything else is skipped the same way
# lazy's fast_check skips it.
#
# By default this is OFFLINE: it reuses the origin refs your last `:Lazy check`
# fetched. So: run `:Lazy check` first, generate the specs cache
# (dump-specs.lua), then run this script. Pass --fetch only if you want it to
# git-fetch per plugin itself; that refreshes the specs again after fetching.
#
# NOTE: written for Termux's restricted `bash` — no process substitution, no
# trap. jq is NOT required (specs cache is already TSV).

set -u

SPEC_FILE="${SPEC_FILE:-$HOME/.cache/lazy-changelog/specs.tsv}"

full=0
limit=0
do_fetch=0
do_refresh=0
no_refresh=0
list_mode=0
filter=""

usage() {
  cat <<'EOF'
Usage: lazy-changelog.sh [--refresh] [--fetch] [--full] [--limit N] [plugin ...]

Prints the changelog (git log) of commits an update would pull for lazy.nvim
plugins behind their update target. Output matches :Lazy check's "Updates".

Options:
  --refresh      regenerate the specs cache via nvim first (run after :Lazy check)
  --no-refresh   trust the existing specs cache, never auto-refresh even if stale
  --fetch        git fetch per plugin, then refresh specs before comparing
                 (redundant if you already ran :Lazy check)
  --full         show date + author + subject instead of oneline
  --limit N      cap changelog commits per plugin (0 = all)
  --list         only list outdated plugins + range + commit count (no log body)
  plugin ...     only scan these plugin names (default: all non-skipped)

Env:
  SPEC_FILE  resolved-specs cache (default: ~/.cache/lazy-changelog/specs.tsv)
             generate with:
               nvim --headless +"lua require('lazy')" \
                       +"luafile <skill>/scripts/dump-specs.lua" +qa
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --fetch) do_fetch=1; shift ;;
    --refresh) do_refresh=1; shift ;;
    --no-refresh) no_refresh=1; shift ;;
    --full)  full=1; shift ;;
    --list)  list_mode=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --limit) [ $# -ge 2 ] || { echo "--limit needs a value" >&2; exit 2; }; limit="$2"; shift 2 ;;
    --limit=*) limit="${1#--limit=}"; shift ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) filter="$filter $1"; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

refresh_specs() {
  bash "$SCRIPT_DIR/refresh-specs.sh"
}

fetch_from_specs() {
  [ -f "$SPEC_FILE" ] || return 0
  printf '%s\n' "$(cat "$SPEC_FILE")" | while IFS='|' read -r name enabled pin is_local dir skip installed target; do
    [ -n "$name" ] || continue
    [ -z "$skip" ] || continue
    [ "$enabled" = "false" ] && continue
    [ -d "$dir/.git" ] || continue
    git -C "$dir" fetch -q --recurse-submodules --tags --force || exit $?
    sleep 0.15 2>/dev/null || :
  done
}

[ -f "$SPEC_FILE" ] || { [ "$no_refresh" = "0" ] && do_refresh=1; }

# Auto-refresh on stale cache (only when not already refreshing/fetching and
# the user did not ask for offline --no-refresh). refresh-specs.sh re-reads
# the refs that :Lazy check/update just wrote, so a refresh here makes the
# offline comparison accurate instead of reporting drift that no longer exists.
if [ "$do_refresh" = "0" ] && [ "$do_fetch" = "0" ] && [ "$no_refresh" = "0" ]; then
  # Portable epoch-seconds mtime: `find -printf '%T@'` works on toybox and GNU
  # (toybox `stat -c %Y` prints "%Y" literally). cut drops the fractional secs.
  mtime() { find "$1" -printf '%T@' 2>/dev/null | cut -d. -f1; }
  specs_mtime=$(mtime "$SPEC_FILE")

  # :Lazy check refreshes origin refs and bumps lazy/state.json's last_check.
  state_file="$HOME/.local/state/nvim/lazy/state.json"
  last_check=""
  [ -f "$state_file" ] && last_check=$(grep -o '"last_check":[0-9]*' "$state_file" 2>/dev/null | head -1 | cut -d: -f2)

  # :Lazy update/sync/restore rewrites lazy-lock.json, so a newer lockfile means
  # the recorded installed commits are stale even with no :Lazy check since.
  lock_file="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lazy-lock.json"
  lock_mtime=$(mtime "$lock_file")

  if { [ -n "$specs_mtime" ] && [ -n "$last_check" ] && [ "$specs_mtime" -lt "$last_check" ] 2>/dev/null; } \
     || { [ -n "$specs_mtime" ] && [ -n "$lock_mtime" ] && [ "$specs_mtime" -lt "$lock_mtime" ] 2>/dev/null; }; then
    do_refresh=1
  fi
fi

# A fetch changes the refs that Git.get_target reads, so refresh the dump after
# fetching. If no dump exists yet, create one first only to discover plugin dirs.
if [ "$do_fetch" = "1" ]; then
  [ -f "$SPEC_FILE" ] || refresh_specs || exit $?
  fetch_from_specs || exit $?
  do_refresh=1
fi

if [ "$do_refresh" = "1" ]; then
  refresh_specs || exit $?
fi

[ -f "$SPEC_FILE" ] || {
  echo "error: specs cache not found: $SPEC_FILE" >&2
  echo "       generate it with dump-specs.lua inside nvim (see --help)" >&2
  exit 1
}

log_fmt="--pretty=format:%h %s (%cr)"
[ "$full" = "1" ] && log_fmt="--pretty=format:%h %ad %an %s"

# Counters: the scan loop runs in a subshell (pipe), so in-memory counters
# won't escape it. Append one byte per event and wc -c later.
cnt_dir="${TMPDIR:-$HOME/.cache}/lazy-changelog.$$"
mkdir -p "$cnt_dir"
c_total="$cnt_dir/total"; c_out="$cnt_dir/outdated"; c_out_names="$cnt_dir/outdated_names"
: > "$c_total"; : > "$c_out"; : > "$c_out_names"

printf '%s\n' "$(cat "$SPEC_FILE")" | while IFS='|' read -r name enabled pin is_local dir skip installed target; do
  [ -n "$name" ] || continue
  [ -z "$skip" ] || continue                # disabled/pin/local/not-installed
  [ "$enabled" = "false" ] && continue
  [ -n "$installed" ] && [ -n "$target" ] || continue

  # optional name filter
  if [ -n "$filter" ]; then
    match=0
    for f in $filter; do [ "$f" = "$name" ] && match=1; done
    [ "$match" = "1" ] || continue
  fi

  [ -d "$dir/.git" ] || continue
  printf x >> "$c_total"

  # Compare like lazy's Git.eq (first 7 chars). installed/target from the
  # dump may be short hashes (e.g. commit="87dcd13"), so also dereference to
  # full hashes for an accurate `git log installed..target` range.
  if [ "${installed:0:7}" != "${target:0:7}" ]; then
    printf x >> "$c_out"
    printf '%s ' "$name" >> "$c_out_names"
    full_inst="$(git -C "$dir" rev-parse -q --verify "${installed}^{commit}" 2>/dev/null)"; [ -n "$full_inst" ] || full_inst="$installed"
    full_tgt="$(git -C "$dir" rev-parse -q --verify "${target}^{commit}" 2>/dev/null)"; [ -n "$full_tgt" ] || full_tgt="$target"
    if [ "$list_mode" = "1" ]; then
      n="$(git -C "$dir" rev-list --count "$full_inst..$full_tgt" 2>/dev/null)"
      printf '%-28s %s..%s  %s commits\n' "$name" "${full_inst:0:8}" "${full_tgt:0:8}" "${n:-?}"
    else
      printf '## %s  %s..%s\n' "$name" "${full_inst:0:8}" "${full_tgt:0:8}"
      if [ "$limit" -gt 0 ] 2>/dev/null; then
        git -C "$dir" log -n "$limit" --no-color --date=short "$log_fmt" "$full_inst..$full_tgt" 2>/dev/null
      else
        git -C "$dir" log --no-color --date=short "$log_fmt" "$full_inst..$full_tgt" 2>/dev/null
      fi
      echo
    fi
  fi
done

echo "----" >&2
n_total="$(wc -c < "$c_total" | tr -d '[:space:]')"; n_out="$(wc -c < "$c_out" | tr -d '[:space:]')"
names="$(cat "$c_out_names" 2>/dev/null)"
names="${names% }"
if [ -n "$names" ]; then
  printf 'outdated=%s scanned=%s : %s\n' "$n_out" "$n_total" "$names" >&2
else
  printf 'outdated=%s scanned=%s  (all up to date)\n' "$n_out" "$n_total" >&2
fi
if [ "$do_fetch" = "1" ]; then
  echo "(fetched plugin refs, refreshed specs, then compared)" >&2
else
  echo "(offline; reuses origin refs from your last :Lazy check)" >&2
fi
rm -rf "$cnt_dir"
