#!/bin/sh

. "$(dirname "$0")/cache-utils.sh"

[ -z "$CODEBUDDY_INTERNET_ENVIRONMENT" ] && exit 0

case "$(uname)" in
Darwin) auth_file=~/Library/Application\ Support/CodeBuddyExtension/Data/Public/auth/Tencent-Cloud.coding-copilot.info ;;
Linux) auth_file=~/.local/share/CodeBuddyExtension/Data/Public/auth/Tencent-Cloud.coding-copilot.info ;;
*) exit 0 ;;
esac

auth_token=$(jq -r '.auth.accessToken // ""' "$auth_file" 2>/dev/null)
enterprise_id=$(jq -r '.account.enterpriseId // ""' "$auth_file" 2>/dev/null)

[ -z "$auth_token" ] && exit 0
[ -z "$enterprise_id" ] && exit 0

cache_file=$(get_cache_file "codebuddy_quota")

cache_get "$cache_file" 60 && exit 0

codebuddy_quota=$(curl -s -X POST "https://www.codebuddy.cn/billing/meter/get-enterprise-user-usage" \
  -H "Authorization: Bearer $auth_token" \
  -H "X-Enterprise-Id: $enterprise_id" \
  -d '{}' 2>/dev/null |
  jq '{
    used: .data.credit,
    limit: .data.limitNum,
    reset_remaining_ms: (if (.data.cycleResetTime // "" | length) > 0 then ((.data.cycleResetTime | strptime("%Y-%m-%d %H:%M:%S") | mktime) - now | . * 1000 | if . > 0 then floor else 0 end) else 0 end)
  }' 2>/dev/null)

echo "$codebuddy_quota" | jq -e '.used' >/dev/null 2>&1 || exit 0

cache_set "$cache_file" "$codebuddy_quota"
