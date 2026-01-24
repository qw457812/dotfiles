#!/bin/sh

. "$(dirname "$0")/cache-utils.sh"

crs_url="$CLAUDE_RELAY_SERVICE_URL"
crs_api_id="$CLAUDE_RELAY_SERVICE_API_ID"

[ -n "$crs_url" ] && [ -n "$crs_api_id" ] || exit 0

case "$ANTHROPIC_BASE_URL" in
"$crs_url"*) ;;
*) exit 0 ;;
esac

cache_file=$(get_cache_file "weekly_cost_$(date +%Y%V)")

cache_get "$cache_file" 60 && exit 0

weekly_cost=$(curl -s -X POST "${crs_url}/apiStats/api/user-model-stats" \
  -H "Content-Type: application/json" \
  -d "{\"apiId\":\"${crs_api_id}\",\"period\":\"weekly\"}" |
  jq -r '[.data[].costs.total] | add // 0')

cache_set "$cache_file" "${weekly_cost:-0}"
