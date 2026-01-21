#!/bin/sh

# cache results to avoid frequent calls since ccusage can be slow

. "$(dirname "$0")/cache-utils.sh"

cache_file=$(get_cache_file "today_cost_$(date +%Y%m%d)")

if cache_get "$cache_file" 60; then
  exit 0
fi

# https://github.com/Wei-Shaw/claude-relay-service/blob/279cd72f232009a96fa5640846824e0a23ec4658/src/routes/apiStats.js#L855
# https://github.com/paceyw/cc-statusbar-for-Claude-Relay-Service/blob/59fa1074a8a04702b80471959d2aa2fa6d0fc9af/admin-html-provider.js#L139-L140
if [ -n "$CLAUDE_RELAY_SERVICE_URL" ] && [ -n "$CLAUDE_RELAY_SERVICE_API_ID" ]; then
  today_cost=$(curl -s -X POST "${CLAUDE_RELAY_SERVICE_URL}/apiStats/api/user-model-stats" \
    -H "Content-Type: application/json" \
    -d "{\"apiId\":\"${CLAUDE_RELAY_SERVICE_API_ID}\",\"period\":\"daily\"}" |
    jq -r '[.data[].costs.total] | add // 0' 2>/dev/null || echo "0")
else
  if command -v ccusage >/dev/null 2>&1; then
    ccusage_cmd="ccusage"
  elif command -v bunx >/dev/null 2>&1; then
    ccusage_cmd="bunx ccusage@latest"
  else
    ccusage_cmd="npx -y ccusage@latest"
  fi
  today=$(date +%Y%m%d)
  # --offline
  # alternative: `ccusage daily --json --order desc 2>/dev/null | jq -r '.daily[0].totalCost // 0' 2>/dev/null`
  today_cost=$($ccusage_cmd daily --json --since "$today" --until "$today" 2>/dev/null | jq -r '.daily[0].totalCost // 0' 2>/dev/null || echo "0")
fi

cache_set "$cache_file" "$today_cost"
