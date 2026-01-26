#!/bin/sh

# date_ago() {
#   date -d "-$1 days" +%Y%m%d 2>/dev/null || date -v"-${1}d" +%Y%m%d
# }
#
# crs_url="$CLAUDE_RELAY_SERVICE_URL"
# [ -n "$crs_url" ] || exit 0
#
# case "$ANTHROPIC_BASE_URL" in
# "$crs_url"*) ;;
# *) exit 0 ;;
# esac
#
# cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
# days_since_monday=$(($(date +%u) - 1))
#
# # Monday: hide weekly cost since it's the same as daily cost
# [ "$days_since_monday" -eq 0 ] && exit 0
#
# # Sum daily costs from Monday to today
# i=$days_since_monday
# while [ $i -ge 0 ]; do
#   f="$cache_dir/daily_cost_$(date_ago $i)_crs.cache"
#   [ -f "$f" ] && cat "$f"
#   i=$((i - 1))
# done | awk '{s+=$1} END {print s+0}'

# NOTE: `natural_weekly` is not officially supported by https://github.com/Wei-Shaw/claude-relay-service/tree/03dfedc3d97b5c00a4c710e214ef89619fa6d6b1

. "$(dirname "$0")/cache-utils.sh"

crs_url="$CLAUDE_RELAY_SERVICE_URL"
crs_api_id="$CLAUDE_RELAY_SERVICE_API_ID"

[ -n "$crs_url" ] && [ -n "$crs_api_id" ] || exit 0

case "$ANTHROPIC_BASE_URL" in
"$crs_url"*) ;;
*) exit 0 ;;
esac

# Monday: hide weekly cost since it's the same as daily cost
[ "$(date +%u)" = "1" ] && exit 0

cache_file=$(get_cache_file "weekly_cost_$(date +%Y%V)_crs")

cache_get "$cache_file" 60 && exit 0

weekly_cost=$(curl -s -X POST "${crs_url}/apiStats/api/user-model-stats" \
  -H "Content-Type: application/json" \
  -d "{\"apiId\":\"${crs_api_id}\",\"period\":\"natural_weekly\"}" |
  jq -r '[.data[].costs.total] | add // 0')

cache_set "$cache_file" "${weekly_cost:-0}"
