#!/bin/sh

today=$(date +%Y%m%d)
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
cache_file="$cache_dir/glm_quota_${today}.cache"
cache_max_age=60

mkdir -p "$cache_dir"

cache_valid=0
if [ -f "$cache_file" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    cache_time=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
  else
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
  fi
  current_time=$(date +%s)
  cache_age=$((current_time - cache_time))
  if [ "$cache_age" -lt "$cache_max_age" ]; then
    cache_valid=1
  fi
fi

if [ "$cache_valid" -eq 1 ]; then
  cat "$cache_file"
else
  # https://github.com/zai-org/zai-coding-plugins/blob/64cebffd62b9ade133a473e5d169e0e8c895441c/plugins/glm-plan-usage/skills/usage-query-skill/scripts/query-usage.mjs
  base_url="$ANTHROPIC_BASE_URL" # https://api.z.ai/api/anthropic
  glm_quota=""

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

  echo "${glm_quota:-}" >"$cache_file"
  echo "${glm_quota:-}"
fi
