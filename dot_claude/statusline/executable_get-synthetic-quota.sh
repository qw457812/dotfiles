#!/bin/sh

. "$(dirname "$0")/cache-utils.sh"

base_url="$ANTHROPIC_BASE_URL" # https://api.synthetic.new/anthropic
auth_token="$ANTHROPIC_AUTH_TOKEN"

case "$base_url" in
*api.synthetic.new*) ;;
*) exit 0 ;;
esac

[ -z "$auth_token" ] && exit 0

cache_file=$(get_cache_file "synthetic_quota")

cache_get "$cache_file" 60 && exit 0

# https://dev.synthetic.new/docs/synthetic/quotas
# "renewsAt": "2026-02-03T13:19:50.957Z"
synthetic_quota=$(curl -s "https://api.synthetic.new/v2/quotas" \
  -H "Authorization: Bearer $auth_token" \
  -H "Content-Type: application/json" 2>/dev/null |
  jq '.subscription | {
    requests: (.requests // 0),
    limit: (.limit // 0),
    renews_remaining_ms: (
      (.renewsAt // "") |
      sub("\\.[0-9]+"; "") |
      sub("\\+00:00$"; "Z") |
      sub("Z$"; "") + "Z" |
      fromdateiso8601 // 0 |
      . - now |
      . * 1000 |
      if . > 0 then floor else 0 end
    )
  }' 2>/dev/null)

echo "$synthetic_quota" | jq -e '.requests' >/dev/null 2>&1 || exit 0

cache_set "$cache_file" "$synthetic_quota"
