#!/bin/sh

# Shared cache utilities for statusline scripts

# Usage: cache_get <cache_file> <max_age_seconds>
# Returns: 0 if cache is valid (and prints cached value), 1 if cache is invalid
cache_get() {
  cache_file="$1"
  cache_max_age="$2"

  if [ ! -f "$cache_file" ]; then
    return 1
  fi

  if [ "$(uname)" = "Darwin" ]; then
    cache_time=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
  else
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
  fi

  current_time=$(date +%s)
  cache_age=$((current_time - cache_time))

  if [ "$cache_age" -lt "$cache_max_age" ]; then
    cat "$cache_file"
    return 0
  fi

  return 1
}

# Usage: cache_set <cache_file> <value>
cache_set() {
  cache_file="$1"
  value="$2"
  mkdir -p "$(dirname "$cache_file")"
  echo "$value" >"$cache_file"
  echo "$value"
}

# Usage: get_cache_file <name>
get_cache_file() {
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  echo "$cache_dir/${1}.cache"
}
