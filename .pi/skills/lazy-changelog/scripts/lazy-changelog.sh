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
# It always re-dumps specs first (headless nvim, ~1s) so installed/target
# reflect lazy's latest resolution and the refs your last `:Lazy check` wrote.
# Run `:Lazy check` in Neovim before this for fresh upstream status; pass
# --fetch to make this script git-fetch each plugin itself instead.
#
# NOTE: written for Termux's restricted `bash` — no process substitution, no
# trap. jq is NOT required (specs cache is already TSV).

set -u

SPEC_FILE="${SPEC_FILE:-$HOME/.cache/lazy-changelog/specs.tsv}"

limit=0
do_fetch=0
list_mode=0
filter=""
usage() {
  cat <<'EOF'
Usage: lazy-changelog.sh [--fetch] [--limit N] [--list] [plugin ...]

Prints the changelog (git log) of commits an update would pull for lazy.nvim
plugins behind their update target. Output matches :Lazy check's "Updates".
Always re-dumps specs first via headless nvim (~1s); run :Lazy check in nvim
beforehand for fresh upstream refs, or pass --fetch to fetch here.

Options:
  --fetch        git fetch per plugin, then refresh specs before comparing
  --limit N      cap changelog commits per plugin (0 = all)
  --list         only list outdated plugins + range + commit count (no log body)
  plugin ...     only scan these plugin names (default: all non-skipped)

Env:
  SPEC_FILE  resolved-specs cache (default: ~/.cache/lazy-changelog/specs.tsv)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --fetch) do_fetch=1; shift ;;
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
  printf '%s\n' "$(cat "$SPEC_FILE")" | while IFS='|' read -r name pin is_local dir url skip installed target; do
    [ -n "$name" ] || continue
    [ -z "$skip" ] || continue
    [ -d "$dir/.git" ] || continue
    git -C "$dir" fetch -q --recurse-submodules --tags --force || exit $?
    sleep 0.15 2>/dev/null || :
  done
}

# --fetch needs a specs file to discover plugin dirs; create one first.
if [ "$do_fetch" = "1" ] && [ ! -f "$SPEC_FILE" ]; then
  refresh_specs || exit $?
  fetch_from_specs || exit $?
fi

# Always re-dump specs (via headless nvim) so installed/target reflect the
# latest lazy resolution and on-disk refs. ~1s; this skill is called rarely.
refresh_specs || exit $?

# Shorten $HOME to ~ for display (the restricted shell skips ${x/#$HOME/~}).
short() { case "$1" in "$HOME"*) printf '~%s' "${1#$HOME}";; *) printf '%s' "$1";; esac; }

log_fmt="--pretty=format:%h %s (%cr)"

# Counters: the scan loop runs in a subshell (pipe), so in-memory counters
# won't escape it. Append one byte per event and wc -c later.
cnt_dir="${TMPDIR:-$HOME/.cache}/lazy-changelog.$$"
mkdir -p "$cnt_dir"
c_total="$cnt_dir/total"; c_out="$cnt_dir/outdated"; c_out_names="$cnt_dir/outdated_names"
: > "$c_total"; : > "$c_out"; : > "$c_out_names"

printf '%s\n' "$(cat "$SPEC_FILE")" | while IFS='|' read -r name pin is_local dir url skip installed target; do
  [ -n "$name" ] || continue
  [ -z "$skip" ] || continue                # pin/local/not-installed
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
      printf '%-28s %s..%s  %s commits  @ %s\n' "$name" "${full_inst:0:8}" "${full_tgt:0:8}" "${n:-?}" "$(short "$dir")"
    else
      printf '## %s  %s..%s  @ %s\n' "$name" "${full_inst:0:8}" "${full_tgt:0:8}" "$(short "$dir")"
      if [ "$limit" -gt 0 ] 2>/dev/null; then
        git -C "$dir" log -n "$limit" --no-color "$log_fmt" "$full_inst..$full_tgt" 2>/dev/null
      else
        git -C "$dir" log --no-color "$log_fmt" "$full_inst..$full_tgt" 2>/dev/null
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
  echo "(fetched refs, re-dumped specs, then compared)" >&2
else
  echo "(re-dumped specs against refs from your last :Lazy check)" >&2
fi
rm -rf "$cnt_dir"
