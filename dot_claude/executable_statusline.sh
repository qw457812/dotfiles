#!/bin/sh

# https://github.com/ryanwclark1/nixos-config/blob/92f5401a93a645792d7d6ba46ef746b5f0128abc/home/features/ai/claude/statusline.sh

input=$(cat)
# echo "$input" >/tmp/statusline_debug.json

if [ -z "$TERMUX_VERSION" ]; then
  # fixes https://github.com/anthropics/claude-code/issues/10375
  [ -n "$TMUX" ] && printf '\ePtmux;\e\e[?1004l\e\\' || printf '\e[?1004l'
fi

# shorter statusline within nvim or termux
if [ "$__IS_CLAUDECODE_NVIM" = "1" ] || [ -n "$TERMUX_VERSION" ]; then
  COLOR_BLUE=$(printf '\033[34m')
  COLOR_CYAN=$(printf '\033[36m')
  COLOR_YELLOW=$(printf '\033[33m')
  COLOR_PINK=$(printf '\033[95m')
  COLOR_RED=$(printf '\033[31m')
  COLOR_GREEN=$(printf '\033[32m')
  COLOR_RESET=$(printf '\033[0m')

  context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
  transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
  # cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

  # model (hidden if Sonnet)
  model=$(echo "$input" | jq -r '(.model.display_name // "") | .[0:1] | ascii_upcase')
  model_display=$([ "$model" != "S" ] && echo "${COLOR_RED}${model}${COLOR_RESET}")

  # NOTE: `context_window.total_input_tokens + context_window.total_output_tokens` is not accurate for now
  # # tokens (from context_window)
  # total_tokens=$(echo "$input" | jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')
  # total_tokens_display="${COLOR_BLUE}$(awk -v t="$total_tokens" 'BEGIN {printf "%.1fk", t/1000}')${COLOR_RESET}"
  # # context usage (from context_window)
  # context_percentage_display="${COLOR_CYAN}$(awk -v t="$total_tokens" -v s="$context_window_size" 'BEGIN {printf "%.1f%%", t*100/s}')${COLOR_RESET}"

  # tokens (from transcript)
  total_tokens=$(cat "$transcript_path" 2>/dev/null | jq -s '
    [.[] | select(.type == "assistant") | .message.usage] | last |
    (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)
  ' || echo 0)
  total_tokens_display="${COLOR_BLUE}$(awk -v t="$total_tokens" 'BEGIN {printf "%.1fk", t/1000}')${COLOR_RESET}"
  # context usage (from transcript)
  context_percentage_display="${COLOR_CYAN}$(awk -v t="$total_tokens" -v s="$context_window_size" 'BEGIN {printf "%.1f%%", t*100/s}')${COLOR_RESET}"

  # session duration (hidden if < 1 min)
  session_duration=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' | awk '{
    s = int($1/1000); if (s < 60) exit
    h = int(s/3600); m = int((s%3600)/60)
    printf "%s", (h > 0 ? h"h"m"m" : m"m")
  }')
  session_duration_display=$([ -n "$session_duration" ] && echo "${COLOR_GREEN}${session_duration}${COLOR_RESET}")

  # session cost
  session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
  session_cost_display="${COLOR_YELLOW}$(printf "\$%.2f" "$session_cost")${COLOR_RESET}"

  # today cost
  today_cost=$("$HOME/.claude/statusline/get-today-cost.sh")
  today_cost_display="${COLOR_PINK}$(printf "\$%.2f" "$today_cost")${COLOR_RESET}"

  # starship (only git status for now)
  # https://github.com/Rolv-Apneseth/starship.yazi/blob/a63550b2f91f0553cc545fd8081a03810bc41bc0/main.lua#L111-L126
  starship_prompt=$(STARSHIP_CONFIG="$HOME/.config/starship-statusline.toml" STARSHIP_SHELL="" starship prompt | tr -d '\n')

  # empty segments are skipped by xargs
  printf '%s\n' "$model_display" "$total_tokens_display" "$context_percentage_display" "$session_duration_display" "$session_cost_display" "$today_cost_display" "$starship_prompt" | xargs
  exit 0
fi

echo "$input" | $(command -v bunx >/dev/null 2>&1 && echo "bunx" || echo "npx -y") ccstatusline@latest
