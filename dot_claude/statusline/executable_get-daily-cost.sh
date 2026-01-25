#!/bin/sh

. "$(dirname "$0")/cache-utils.sh"

today=$(date +%Y%m%d)
crs_url="$CLAUDE_RELAY_SERVICE_URL"
crs_api_id="$CLAUDE_RELAY_SERVICE_API_ID"

source="ccusage"
if [ -n "$crs_url" ] && [ -n "$crs_api_id" ]; then
  case "$ANTHROPIC_BASE_URL" in
  "$crs_url"*) source="crs" ;;
  esac
fi

cache_file=$(get_cache_file "daily_cost_${today}_${source}")

cache_get "$cache_file" 60 && exit 0

if [ "$source" = "crs" ]; then
  # https://github.com/Wei-Shaw/claude-relay-service/blob/279cd72f232009a96fa5640846824e0a23ec4658/src/routes/apiStats.js#L855
  # https://github.com/paceyw/cc-statusbar-for-Claude-Relay-Service/blob/59fa1074a8a04702b80471959d2aa2fa6d0fc9af/admin-html-provider.js#L139-L140
  daily_cost=$(curl -s -X POST "${crs_url}/apiStats/api/user-model-stats" \
    -H "Content-Type: application/json" \
    -d "{\"apiId\":\"${crs_api_id}\",\"period\":\"daily\"}" |
    jq -r '[.data[].costs.total] | add // 0')
else
  if command -v ccusage >/dev/null 2>&1; then
    ccusage_cmd="ccusage"
  elif command -v bunx >/dev/null 2>&1; then
    ccusage_cmd="bunx ccusage@latest"
  else
    ccusage_cmd="npx -y ccusage@latest"
  fi
  # alternative: `ccusage daily --json --order desc 2>/dev/null | jq -r '.daily[0].totalCost // 0'`
  daily_cost=$($ccusage_cmd daily --json --since "$today" --until "$today" 2>/dev/null | jq -r '.daily[0].totalCost // 0')
fi

cache_set "$cache_file" "${daily_cost:-0}"
