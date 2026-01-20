#!/bin/sh

# https://github.com/ryanwclark1/nixos-config/blob/92f5401a93a645792d7d6ba46ef746b5f0128abc/home/features/ai/claude/statusline.sh
# https://github.com/jarrodwatts/claude-hud

input=$(cat)
# echo "$input" >/tmp/statusline_debug.json

if [ -z "$TERMUX_VERSION" ]; then
  # fixes https://github.com/anthropics/claude-code/issues/10375
  [ -n "$TMUX" ] && printf '\ePtmux;\e\e[?1004l\e\\' || printf '\e[?1004l'
fi

# shorter statusline within nvim or termux
if [ "$__IS_CLAUDECODE_NVIM" = "1" ] || [ -n "$TERMUX_VERSION" ]; then
  COLOR_RED=$(printf '\033[31m')
  COLOR_GREEN=$(printf '\033[32m')
  COLOR_YELLOW=$(printf '\033[33m')
  COLOR_BLUE=$(printf '\033[34m')
  COLOR_CYAN=$(printf '\033[36m')
  COLOR_TEAL=$(printf '\033[38;5;73m')
  COLOR_ORANGE=$(printf '\033[38;5;209m')
  COLOR_GRAY=$(printf '\033[38;5;248m')
  COLOR_RESET=$(printf '\033[0m')

  context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
  transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
  # cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

  # vim mode
  vim_mode=$(echo "$input" | jq -r '.vim.mode // ""')
  case "$vim_mode" in
  INSERT) vim_mode_display="${COLOR_GREEN}I${COLOR_RESET}" ;;
  NORMAL) vim_mode_display="${COLOR_BLUE}N${COLOR_RESET}" ;;
  *) vim_mode_display=$([ -n "$vim_mode" ] && echo "${vim_mode}") ;;
  esac

  # model
  case "$ANTHROPIC_BASE_URL" in
  "" | "$CLAUDE_RELAY_SERVICE_URL"*) ;;
  *) model=$(cat "$transcript_path" 2>/dev/null | jq -r 'select(.type == "assistant") | .message.model // empty' | tail -1) ;; # z.ai
  esac
  model=${model:-$(echo "$input" | jq -r '(.model.display_name // "") | split(" ")[0] | split("-")[0] | (.[:1] | ascii_upcase) + .[1:]')}
  model_display=$([ -n "$model" ] && echo "${COLOR_RED}${model}${COLOR_RESET}")

  # # tokens (from transcript)
  # total_tokens=$(cat "$transcript_path" 2>/dev/null | jq -s '
  #   [.[] | select(.type == "assistant") | .message.usage] | last |
  #   (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
  # ' || echo 0)
  # tokens (from context_window)
  total_tokens=$(echo "$input" | jq -r '.context_window.current_usage | (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)')
  total_tokens_display="${COLOR_BLUE}$(awk -v t="$total_tokens" 'BEGIN {printf "%.1fk", t/1000}')${COLOR_RESET}"

  # context usage
  context_percentage_display="${COLOR_CYAN}$(awk -v t="$total_tokens" -v s="$context_window_size" 'BEGIN {printf "%.1f%%", t*100/s}')${COLOR_RESET}"

  # session cost
  session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
  session_cost_display="${COLOR_YELLOW}$(printf "\$%.2f" "$session_cost")${COLOR_RESET}"

  # today cost
  today_cost=$("$HOME/.claude/statusline/get-today-cost.sh")
  today_cost_display="${COLOR_ORANGE}$(printf "\$%.2f" "$today_cost")${COLOR_RESET}"

  # session duration (hidden if < 1 min)
  session_duration=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' | awk '{
    s = int($1/1000); if (s < 60) exit
    h = int(s/3600); m = int((s%3600)/60)
    printf "%s", (h > 0 ? h"h"m"m" : m"m")
  }')
  session_duration_display=$([ -n "$session_duration" ] && echo "${COLOR_TEAL}${session_duration}${COLOR_RESET}")

  # version
  version=$(echo "$input" | jq -r '.version // ""')
  version_display=$([ -n "$version" ] && echo "${COLOR_GRAY}v${version}${COLOR_RESET}")

  # changes: lines changed (for nvim) or starship git status (for termux)
  if [ "$__IS_CLAUDECODE_NVIM" = "1" ]; then
    lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
    lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
    # hide if no changes
    changes_display=""
    [ "$lines_added" -gt 0 ] && changes_display="${COLOR_GREEN}+${lines_added}${COLOR_RESET}"
    [ "$lines_removed" -gt 0 ] && changes_display="${changes_display}${changes_display:+ }${COLOR_RED}-${lines_removed}${COLOR_RESET}"
  else
    # https://github.com/Rolv-Apneseth/starship.yazi/blob/a63550b2f91f0553cc545fd8081a03810bc41bc0/main.lua#L111-L126
    changes_display=$(STARSHIP_CONFIG="$HOME/.config/starship-statusline.toml" STARSHIP_SHELL="" starship prompt | tr -d '\n')
  fi

  # empty segments are skipped by xargs
  printf '%s\n' \
    "$vim_mode_display" \
    "$model_display" \
    "$total_tokens_display" \
    "$context_percentage_display" \
    "$session_cost_display" \
    "$today_cost_display" \
    "$session_duration_display" \
    "$version_display" \
    "$changes_display" | xargs
  exit 0
fi

echo "$input" | $(command -v bunx >/dev/null 2>&1 && echo "bunx" || echo "npx -y") ccstatusline@latest
