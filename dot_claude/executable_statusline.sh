#!/bin/sh

# https://github.com/ryanwclark1/nixos-config/blob/92f5401a93a645792d7d6ba46ef746b5f0128abc/home/features/ai/claude/statusline.sh

input=$(cat)
# echo "$input" >/tmp/statusline_debug.json

# cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# fixes https://github.com/anthropics/claude-code/issues/10375
if [ -z "$TERMUX_VERSION" ]; then
  if [ -n "$TMUX" ]; then
    printf '\ePtmux;\e\e[?1004l\e\\'
  else
    printf '\e[?1004l'
  fi
fi

# shorter statusline within nvim or termux
if [ "$__IS_CLAUDECODE_NVIM" = "1" ] || [ -n "$TERMUX_VERSION" ]; then
  transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

  # tokens
  total_tokens=$(cat "$transcript_path" 2>/dev/null | jq -s '
    [.[] | select(.type == "assistant") | .message.usage] | last |
    (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)
  ' || echo 0)
  total_tokens_display=$(awk -v t="$total_tokens" 'BEGIN {printf "\033[34m%.1fk\033[0m", t/1000}') # blue

  # context usage
  context_percentage=$(awk -v t="$total_tokens" 'BEGIN {printf "%.1f", t*100/200000}')
  context_percentage_display=$(printf "\033[36m%s%%\033[0m" "$context_percentage") # cyan

  # TODO: add session-clock

  # session cost
  session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
  session_cost_display=$(printf "\033[33m\$%.2f\033[0m" "$session_cost") # yellow

  # today cost
  today_cost=$("$HOME/.claude/statusline/get-today-cost.sh")
  today_cost_display=$(printf "\033[35m\$%.2f\033[0m" "$today_cost") # purple

  # starship, only git status for now
  # https://github.com/Rolv-Apneseth/starship.yazi/blob/a63550b2f91f0553cc545fd8081a03810bc41bc0/main.lua#L111-L126
  starship_prompt=$(STARSHIP_CONFIG="$HOME/.config/starship-statusline.toml" STARSHIP_SHELL="" starship prompt | tr -d '\n')

  printf '%s %s %s %s %s\n' "$total_tokens_display" "$context_percentage_display" "$session_cost_display" "$today_cost_display" "$starship_prompt"
  exit 0
fi

if command -v bunx >/dev/null 2>&1; then
  echo "$input" | bunx ccstatusline
else
  echo "$input" | npx -y ccstatusline
fi
