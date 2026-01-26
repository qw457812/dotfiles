#!/bin/sh

date_ago() {
  date -d "-$1 days" +%Y%m%d 2>/dev/null || date -v"-${1}d" +%Y%m%d
}

crs_url="$CLAUDE_RELAY_SERVICE_URL"
[ -n "$crs_url" ] || exit 0

case "$ANTHROPIC_BASE_URL" in
"$crs_url"*) ;;
*) exit 0 ;;
esac

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
days_since_monday=$(($(date +%u) - 1))

# Monday: hide weekly cost since it's the same as daily cost
[ "$days_since_monday" -eq 0 ] && exit 0

# Sum daily costs from Monday to today
i=$days_since_monday
while [ $i -ge 0 ]; do
  f="$cache_dir/daily_cost_$(date_ago $i)_crs.cache"
  [ -f "$f" ] && cat "$f"
  i=$((i - 1))
done | awk '{s+=$1} END {print s+0}'
