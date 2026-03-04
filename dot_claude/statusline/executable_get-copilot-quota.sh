#!/bin/sh

. "$(dirname "$0")/cache-utils.sh"

oauth_token=$(jq -r '.[] | select(.oauth_token) | .oauth_token' ~/.config/github-copilot/apps.json 2>/dev/null | head -1)

[ -z "$oauth_token" ] && exit 0

cache_file=$(get_cache_file "copilot_quota")

cache_get "$cache_file" 180 && exit 0

# https://github.com/olimorris/codecompanion.nvim/blob/ed367944ece02d0ab2a2552ba3ad0b092f1a2144/lua/codecompanion/adapters/http/copilot/stats.lua#L31
copilot_quota=$(curl -s "https://api.github.com/copilot_internal/user" \
  -H "Authorization: Bearer $oauth_token" 2>/dev/null |
  jq '{
    used: (.quota_snapshots.premium_interactions.entitlement - .quota_snapshots.premium_interactions.remaining),
    limit: .quota_snapshots.premium_interactions.entitlement,
    reset_remaining_ms: ((.quota_reset_date_utc | sub("\\.[0-9]+"; "") | fromdateiso8601) - now | . * 1000 | if . > 0 then floor else 0 end)
  }' 2>/dev/null)

echo "$copilot_quota" | jq -e '.used' >/dev/null 2>&1 || exit 0

cache_set "$cache_file" "$copilot_quota"
