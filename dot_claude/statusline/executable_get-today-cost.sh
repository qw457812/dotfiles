#!/bin/sh

# cache results to avoid frequent calls since ccusage can be slow

today=$(date +%Y%m%d)
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
cache_file="$cache_dir/today_cost_${today}.cache"
cache_max_age=60 # seconds

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
  if command -v ccusage >/dev/null 2>&1; then
    ccusage_cmd="ccusage"
  elif command -v bunx >/dev/null 2>&1; then
    ccusage_cmd="bunx ccusage@latest"
  else
    ccusage_cmd="npx -y ccusage@latest"
  fi
  # --offline
  # alternative: `ccusage daily --json --order desc 2>/dev/null | jq -r '.daily[0].totalCost // 0' 2>/dev/null`
  today_cost=$($ccusage_cmd daily --json --since "$today" --until "$today" 2>/dev/null | jq -r '.daily[0].totalCost // 0' 2>/dev/null || echo "0")
  echo "$today_cost" >"$cache_file"
  echo "$today_cost"
fi
