#!/bin/sh

. "$(dirname "$0")/cache-utils.sh"

base_url="$ANTHROPIC_BASE_URL" # https://api.z.ai/api/anthropic
auth_token="$ANTHROPIC_AUTH_TOKEN"

case "$base_url" in
*api.z.ai* | *open.bigmodel.cn* | *dev.bigmodel.cn*) ;;
*localhost*) # for LiteLLM
  base_url="https://api.z.ai/api/anthropic"
  auth_token="$ZAI_API_KEY"
  ;;
*) exit 0 ;;
esac

[ -z "$auth_token" ] && exit 0

cache_file=$(get_cache_file "glm_quota")

cache_get "$cache_file" 180 && exit 0

# https://github.com/zai-org/zai-coding-plugins/blob/64cebffd62b9ade133a473e5d169e0e8c895441c/plugins/glm-plan-usage/skills/usage-query-skill/scripts/query-usage.mjs
glm_quota=$(curl -s "https://$(echo "$base_url" | cut -d'/' -f3)/api/monitor/usage/quota/limit" \
  -H "Authorization: $auth_token" \
  -H "Content-Type: application/json" 2>/dev/null |
  jq -r '[.data.limits[] | {(.type): .percentage}] | add | {token: (.TOKENS_LIMIT // 0), mcp: (.TIME_LIMIT // 0)}' 2>/dev/null)

echo "$glm_quota" | jq -e '.token' >/dev/null 2>&1 || exit 0

cache_set "$cache_file" "$glm_quota"
