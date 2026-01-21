#!/bin/sh

. "$(dirname "$0")/cache-utils.sh"

cache_file=$(get_cache_file "glm_quota")

if cache_get "$cache_file" 120; then
  exit 0
fi

# https://github.com/zai-org/zai-coding-plugins/blob/64cebffd62b9ade133a473e5d169e0e8c895441c/plugins/glm-plan-usage/skills/usage-query-skill/scripts/query-usage.mjs
base_url="$ANTHROPIC_BASE_URL" # https://api.z.ai/api/anthropic
case "$base_url" in
*api.z.ai* | *open.bigmodel.cn* | *dev.bigmodel.cn*)
  if [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
    domain=$(echo "$base_url" | cut -d'/' -f3)
    glm_quota=$(curl -s "https://${domain}/api/monitor/usage/quota/limit" \
      -H "Authorization: $ANTHROPIC_AUTH_TOKEN" \
      -H "Content-Type: application/json" 2>/dev/null |
      jq -r '.data.limits[] | select(.type == "TOKENS_LIMIT") | .percentage' 2>/dev/null || echo "")
  fi
  ;;
esac

cache_set "$cache_file" "${glm_quota:-}"
