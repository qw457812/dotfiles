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
# It always re-dumps specs first (headless nvim) so installed/target
# reflect lazy's latest resolution and the refs your last `:Lazy check` wrote.
# Run `:Lazy check` in Neovim first for fresh upstream status (or headless:
# `nvim --headless +"Lazy! check" +qa`).
#
# NOTE: written for Termux's restricted `bash` — no process substitution, no
# trap. jq is NOT required (specs cache is already TSV).

set -u

SPEC_FILE="${SPEC_FILE:-$HOME/.cache/lazy-changelog/specs.tsv}"

limit=0
list_mode=0
filter=""
usage() {
  cat <<'EOF'
Usage: lazy-changelog.sh [--limit N] [--list] [plugin ...]

Prints the changelog (git log) of commits an update would pull for lazy.nvim
plugins behind their update target. Output matches :Lazy check's "Updates".
Always re-dumps specs first via headless nvim. Run :Lazy check in nvim
beforehand for fresh upstream refs.

Options:
  --limit N      cap changelog commits per plugin (0 = all)
  --list         only list outdated plugins + range + commit count (no log body)
  plugin ...     only scan these plugin names (default: all non-skipped)

Env:
  SPEC_FILE  resolved-specs cache (default: ~/.cache/lazy-changelog/specs.tsv)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list)  list_mode=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --limit) [ $# -ge 2 ] || { echo "--limit needs a value" >&2; exit 2; }; limit="$2"; shift 2 ;;
    --limit=*) limit="${1#--limit=}"; shift ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) filter="$filter $1"; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# refresh_specs — re-dump lazy's (installed, target) via headless nvim, so the
# scan reflects lazy's latest resolution and the on-disk refs your last
# :Lazy check wrote. Called once per run (this skill is called rarely).
# Writes atomically via a tmp file; nvim's own stdout (iTerm2 OSC sequences,
# plugin chatter) is sent to /dev/null and can never reach the data. Writes a
# one-line "wrote N plugins" status to stderr; on failure writes the error to
# stderr and exits non-zero. (Runs in the command-substitution subshell below,
# so its vars don't leak and its exit propagates as the captured $?.)
refresh_specs() {
  dump_lua="$SCRIPT_DIR/dump-specs.lua"
  [ -f "$dump_lua" ] || { echo "error: dump-specs.lua missing: $dump_lua" >&2; exit 1; }

  # locate nvim: explicit $NVIM, else PATH, else common install paths (Termux,
  # bob, Homebrew, system).
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

  mkdir -p "$(dirname "$SPEC_FILE")"
  tmp="${SPEC_FILE}.$$"

  # dump-specs.lua writes the TSV straight to $tmp (via lazy.util.write_file)
  # when LAZY_CHANGELOG_SPEC_FILE is set, so nvim's own stdout never reaches
  # the data — only $tmp is the source of truth.
  #
  # NVIM_LOG_FILE is pinned next to $SPEC_FILE (an already-writable cache dir):
  # nvim otherwise writes ./nvim.log in its cwd, and we never cd, so it would
  # land wherever the caller ran from (the repo tree).
  rc=0
  NVIM_LOG_FILE="$(dirname "$SPEC_FILE")/nvim.log" \
    LAZY_CHANGELOG_SPEC_FILE="$tmp" \
    "$nvim" --headless +"luafile $dump_lua" +qa >/dev/null 2>&1 || rc=$?

  if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then
    echo "error: nvim headless run failed (exit $rc) or wrote no output." >&2
    echo "       try: LAZY_CHANGELOG_SPEC_FILE=$tmp $nvim --headless +luafile $dump_lua +qa" >&2
    rm -f "$tmp"
    [ "$rc" -ne 0 ] || rc=1
    exit "$rc"
  fi

  mv "$tmp" "$SPEC_FILE"
  echo "wrote $(wc -l < "$SPEC_FILE" | tr -d ' ') plugins to $SPEC_FILE" >&2
}

# Always re-dump specs first (see refresh_specs above). Capture its stderr: on
# failure surface it; on success suppress the "wrote N plugins" line (the
# footer reports the count) so report output (stdout) stays clean and all
# status is grouped at the end.
refresh_err="$(refresh_specs 2>&1)" || { echo "$refresh_err" >&2; exit $?; }

# Shorten $HOME to ~ for display (the restricted shell skips ${x/#$HOME/~}).
short() { case "$1" in "$HOME"*) printf '~%s' "${1#$HOME}";; *) printf '%s' "$1";; esac; }

log_fmt="--pretty=format:%h %s (%cr)"

# Counters: the scan loop runs in a subshell (pipe), so in-memory counters
# won't escape it. Append one byte per event and wc -c later.
cnt_dir="${TMPDIR:-$HOME/.cache}/lazy-changelog.$$"
mkdir -p "$cnt_dir"
c_total="$cnt_dir/total"; c_out="$cnt_dir/outdated"; c_out_names="$cnt_dir/outdated_names"
c_skip="$cnt_dir/skipped"; c_skip_reasons="$cnt_dir/skip_reasons"; c_ignored="$cnt_dir/ignored"
: > "$c_total"; : > "$c_out"; : > "$c_out_names"; : > "$c_skip"; : > "$c_skip_reasons"; : > "$c_ignored"

printf '%s\n' "$(cat "$SPEC_FILE")" | while IFS='|' read -r name pin is_local dir url skip installed target; do
  [ -n "$name" ] || { printf x >> "$c_ignored"; continue; }   # blank/garbage line

  # optional name filter — apply before skip/anomaly counting so the summary's
  # scanned/skipped/ignored refer only to the filtered set.
  if [ -n "$filter" ]; then
    match=0
    for f in $filter; do [ "$f" = "$name" ] && match=1; done
    [ "$match" = "1" ] || continue
  fi

  [ -z "$skip" ] || {                                         # pin/local/not-installed
    printf x >> "$c_skip"; printf '%s ' "$skip" >> "$c_skip_reasons"; continue
  }

  [ -n "$installed" ] && [ -n "$target" ] || { printf x >> "$c_ignored"; continue; }
  [ -d "$dir/.git" ] || { printf x >> "$c_ignored"; continue; }
  printf x >> "$c_total"

  # Compare like lazy's Git.eq (first 7 chars). installed/target from the
  # dump may be short hashes (e.g. commit="87dcd13"), so also dereference to
  # full hashes for an accurate `git log installed..target` range.
  if [ "${installed:0:7}" != "${target:0:7}" ]; then
    printf x >> "$c_out"
    printf '%s ' "$name" >> "$c_out_names"
    full_inst="$(git -C "$dir" rev-parse -q --verify "${installed}^{commit}" 2>/dev/null)"; [ -n "$full_inst" ] || full_inst="$installed"
    full_tgt="$(git -C "$dir" rev-parse -q --verify "${target}^{commit}" 2>/dev/null)"; [ -n "$full_tgt" ] || full_tgt="$target"
    # short host path (e.g. github.com/owner/repo, gitlab.com/group/repo) for
    # follow-up links (compare/PR/issue). Derived from the spec's origin url
    # (Git.get_origin = the actual remote), so host is kept — github-only
    # normalization would hide the host of gitlab/etc plugins.
    # NOTE: feed sed via a here-string — never `printf '%s' "$url" | sed`.
    # A pipe inside this $(...) inherits the pipe-fed while-read loop's stdin
    # (the specs data) and drains it, so `read` hits EOF after the first
    # outdated plugin and `scanned=` underreports (2/9/37... instead of 138).
    # The usual fixes are blocked by just-bash (the interpreter these scripts
    # run under): `<(...)` is rejected by its parser ("Parse error: Expected
    # redirection target") and a loop on a separate fd (`<&3`/`3<`) fails at
    # runtime ("Bad file descriptor") — same constraint as the Termux
    # "no process substitution" note at the top of this file. `<<<` is
    # just-bash-legal and has no inner pipe, so it can't drain the loop stdin.
    repo="$(sed -E 's#\.git$##; s#^[a-z]+://##; s#^[^@/]+@##; s#:#/#' <<<"$url")"
    repo_tag=""; [ -n "$repo" ] && repo_tag="  ($repo)"
    if [ "$list_mode" = "1" ]; then
      n="$(git -C "$dir" rev-list --count "$full_inst..$full_tgt" 2>/dev/null)"
      printf '%-28s %s..%s  %s commits  @ %s%s\n' "$name" "${full_inst:0:8}" "${full_tgt:0:8}" "${n:-?}" "$(short "$dir")" "$repo_tag"
    else
      printf '## %s  %s..%s  @ %s%s\n' "$name" "${full_inst:0:8}" "${full_tgt:0:8}" "$(short "$dir")" "$repo_tag"
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
n_skip="$(wc -c < "$c_skip" | tr -d '[:space:]')"; n_ign="$(wc -c < "$c_ignored" | tr -d '[:space:]')"
names="$(cat "$c_out_names" 2>/dev/null)"; names="${names% }"
skip_summary=""
if [ -n "$n_skip" ] && [ "$n_skip" != "0" ]; then
  pin_n=0; loc_n=0; ni_n=0
  for r in $(cat "$c_skip_reasons" 2>/dev/null); do
    case "$r" in
      pin) pin_n=$((pin_n+1)) ;; local) loc_n=$((loc_n+1)) ;; not-installed) ni_n=$((ni_n+1)) ;;
    esac
  done
  brk=""
  [ "$pin_n" = "0" ] || brk="$brk pin:$pin_n"
  [ "$loc_n" = "0" ] || brk="$brk local:$loc_n"
  [ "$ni_n" = "0" ] || brk="$brk not-installed:$ni_n"
  brk="${brk# }"
  skip_summary=" skipped=$n_skip"
  [ -n "$brk" ] && skip_summary="$skip_summary ($brk)"
fi
[ -n "$n_ign" ] && [ "$n_ign" != "0" ] && skip_summary="$skip_summary ignored=$n_ign"
n_specs="$(wc -l < "$SPEC_FILE" | tr -d '[:space:]')"
if [ -n "$names" ]; then
  printf 'outdated=%s scanned=%s%s : %s\n' "$n_out" "$n_total" "$skip_summary" "$names" >&2
else
  printf 'outdated=%s scanned=%s%s  (all up to date)\n' "$n_out" "$n_total" "$skip_summary" >&2
fi
printf '(re-dumped %s specs via headless nvim -> %s; refs from your last :Lazy check)\n' "$n_specs" "$(short "$SPEC_FILE")" >&2
rm -rf "$cnt_dir"
