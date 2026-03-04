#!/bin/sh

# https://github.com/ryanwclark1/nixos-config/blob/92f5401a93a645792d7d6ba46ef746b5f0128abc/home/features/ai/claude/statusline.sh
# https://github.com/gqy20/cc_plugins/blob/d5fbcd844847b320dc4207ad841ae7a3c18dd222/.claude/statusline.sh
# https://github.com/jarrodwatts/claude-hud
# https://github.com/OpenRouterTeam/openrouter-examples/blob/main/claude-code/statusline.ts

input=$(cat)
# echo "$input" >/tmp/statusline_debug.json

# shorter statusline within nvim or termux
if [ "$__IS_CLAUDECODE_NVIM" = "1" ] || [ -n "$TERMUX_VERSION" ]; then
  COLOR_RED=$(printf '\033[31m')
  COLOR_GREEN=$(printf '\033[32m')
  COLOR_YELLOW=$(printf '\033[33m')
  COLOR_BLUE=$(printf '\033[34m')
  COLOR_CYAN=$(printf '\033[36m')
  COLOR_TEAL=$(printf '\033[38;5;73m')
  # COLOR_GOLD=$(printf '\033[38;5;136m')
  COLOR_ORANGE=$(printf '\033[38;5;209m')
  COLOR_MAGENTA=$(printf '\033[38;5;213m')
  # COLOR_SEAFOAM=$(printf '\033[38;5;107m')
  COLOR_SKY=$(printf '\033[38;5;81m')
  COLOR_AQUAMARINE=$(printf '\033[38;5;122m')
  COLOR_BRONZE=$(printf '\033[38;5;130m')
  COLOR_LAVENDER=$(printf '\033[38;5;147m')
  COLOR_GRAY=$(printf '\033[38;5;248m')
  COLOR_MAUVE=$(printf '\033[38;5;96m')
  COLOR_STEEL=$(printf '\033[38;5;67m')
  COLOR_CERULEAN=$(printf '\033[38;5;74m')
  COLOR_RESET=$(printf '\033[0m')

  format_ms() {
    echo "$1" | awk '{
      s = int($1/1000)
      if (s < 60) {
        printf "<1m"
      } else {
        d = int(s/86400)
        h = int((s%86400)/3600)
        m = int((s%3600)/60)
        if (d > 0) {
          printf "%dd%dh%dm", d, h, m
        } else if (h > 0) {
          printf "%dh%dm", h, m
        } else {
          printf "%dm", m
        }
      }
    }'
  }

  base_url="$ANTHROPIC_BASE_URL"
  context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
  transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
  # cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

  # vim mode
  vim_mode=$(echo "$input" | jq -r '.vim.mode // ""')
  case "$vim_mode" in
  INSERT) vim_mode_display="${COLOR_AQUAMARINE}I${COLOR_RESET}" ;;
  NORMAL) vim_mode_display="${COLOR_SKY}N${COLOR_RESET}" ;;
  *) vim_mode_display=$([ -n "$vim_mode" ] && echo "${vim_mode}") ;;
  esac

  # model
  model=""
  if [ -n "$base_url" ] && [ "${base_url#"$CLAUDE_RELAY_SERVICE_URL"}" = "$base_url" ]; then
    model=$(cat "$transcript_path" 2>/dev/null | jq -r 'select(.type == "assistant") | .message.model // empty' | tail -1) # z.ai
  fi
  model=${model:-$(echo "$input" | jq -r '.model.display_name // .model.id // empty')}
  case "$base_url" in *api.synthetic.new* | *localhost*) model=${model##*/} ;; esac
  model_display=$([ -n "$model" ] && echo "${COLOR_LAVENDER}${model}${COLOR_RESET}")

  # tokens
  total_tokens=$(echo "$input" | jq -r '.context_window.current_usage | (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)')
  total_tokens_display="${COLOR_BLUE}$(awk -v t="$total_tokens" 'BEGIN {printf "%.1fk", t/1000}')${COLOR_RESET}"

  # context usage
  context_percentage_display="${COLOR_CYAN}$(awk -v t="$total_tokens" -v s="$context_window_size" 'BEGIN {printf "%.1f%%", t*100/s}')${COLOR_RESET}"

  # # session cost
  # session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
  # session_cost_display="${COLOR_GOLD}$(printf "\$%.2f" "$session_cost")${COLOR_RESET}"

  # # daily cost (mainly for CRS)
  # daily_cost=$("$HOME/.claude/statusline/get-daily-cost.sh")
  # daily_cost_display=$([ "$daily_cost" != "0" ] && echo "${COLOR_ORANGE}$(printf "\$%.2f" "$daily_cost")${COLOR_RESET}")

  # # weekly cost (only for CRS; hidden on Monday)
  # weekly_cost=$("$HOME/.claude/statusline/get-weekly-cost.sh")
  # weekly_cost_display=$([ -n "$weekly_cost" ] && echo "${COLOR_BRONZE}$(printf "\$%.2f" "$weekly_cost")${COLOR_RESET}")

  # synthetic quota (only for synthetic)
  syn_quota=$("$HOME/.claude/statusline/get-synthetic-quota.sh")
  syn_quota_display=""
  if echo "$syn_quota" | jq -e . >/dev/null 2>&1; then
    syn_sub_used=$(echo "$syn_quota" | jq -r '.sub.used // 0')
    syn_sub_limit=$(echo "$syn_quota" | jq -r '.sub.limit // 0')
    syn_sub_reset_ms=$(echo "$syn_quota" | jq -r '.sub.reset_remaining_ms // 0')
    syn_sub_display="${COLOR_MAGENTA}${syn_sub_used}${COLOR_RESET}${COLOR_MAUVE}/${syn_sub_limit} $(format_ms "$syn_sub_reset_ms")${COLOR_RESET}"

    syn_tc_used=$(echo "$syn_quota" | jq -r '.tool_calls.used // 0')
    syn_tc_limit=$(echo "$syn_quota" | jq -r '.tool_calls.limit // 0')
    syn_tc_reset_ms=$(echo "$syn_quota" | jq -r '.tool_calls.reset_remaining_ms // 0')
    syn_tc_display="${COLOR_MAGENTA}${syn_tc_used}${COLOR_RESET}${COLOR_MAUVE}/${syn_tc_limit} $(format_ms "$syn_tc_reset_ms")${COLOR_RESET}"

    syn_quota_display="${syn_sub_display} ${syn_tc_display}"
  fi

  # glm quota (only for ZAI/ZHIPU)
  glm_quota=$("$HOME/.claude/statusline/get-glm-quota.sh")
  glm_quota_display=""
  if echo "$glm_quota" | jq -e . >/dev/null 2>&1; then
    glm_tokens_display=$(
      echo "$glm_quota" | jq -r '.tokens[] | "\(.used_pct) \(.reset_remaining_ms)"' |
        while read -r pct ms; do
          printf '%s%s%%%s%s/%s%s ' \
            "$COLOR_ORANGE" "$pct" "$COLOR_RESET" \
            "$COLOR_BRONZE" "$(format_ms "$ms")" "$COLOR_RESET"
        done | xargs
    )
    glm_mcp=$(echo "$glm_quota" | jq -r '.mcp.used_pct // 0')
    glm_quota_display=$([ -n "$glm_tokens_display" ] && echo "$glm_tokens_display${glm_mcp:+ ${COLOR_YELLOW}${glm_mcp}%${COLOR_RESET}}")
  fi

  # copilot premium quota
  copilot_quota=$("$HOME/.claude/statusline/get-copilot-quota.sh")
  copilot_quota_display=""
  if echo "$copilot_quota" | jq -e . >/dev/null 2>&1; then
    copilot_used=$(echo "$copilot_quota" | jq -r '.used // 0')
    copilot_limit=$(echo "$copilot_quota" | jq -r '.limit // 0')
    copilot_reset_ms=$(echo "$copilot_quota" | jq -r '.reset_remaining_ms // 0')
    copilot_quota_display="${COLOR_CERULEAN}${copilot_used}${COLOR_RESET}${COLOR_STEEL}/${copilot_limit} $(format_ms "$copilot_reset_ms")${COLOR_RESET}"
  fi

  # version
  version=$(echo "$input" | jq -r '.version // ""')
  version_display=$([ -n "$version" ] && echo "${COLOR_GRAY}v${version}${COLOR_RESET}")

  # session duration
  session_duration=$(format_ms "$(echo "$input" | jq -r '.cost.total_duration_ms // 0')")
  session_duration_display=$([ -n "$session_duration" ] && echo "${COLOR_TEAL}${session_duration}${COLOR_RESET}")

  # changes: lines changed (for nvim) or starship git status (for termux)
  if [ "$__IS_CLAUDECODE_NVIM" = "1" ]; then
    lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
    lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
    # hidden if no changes
    changes_display=""
    [ "$lines_added" -gt 0 ] && changes_display="${COLOR_GREEN}+${lines_added}${COLOR_RESET}"
    [ "$lines_removed" -gt 0 ] && changes_display="${changes_display}${changes_display:+ }${COLOR_RED}-${lines_removed}${COLOR_RESET}"
  else
    # https://github.com/Rolv-Apneseth/starship.yazi/blob/a63550b2f91f0553cc545fd8081a03810bc41bc0/main.lua#L111-L126
    changes_display=$(STARSHIP_CONFIG="$HOME/.config/starship-statusline.toml" STARSHIP_SHELL="" starship prompt | tr -d '\n')
  fi

  # GSD update available?
  # https://github.com/gsd-build/get-shit-done/blob/2eaed7a8475839958f9ec76ca4c26d9a0bbfc33f/hooks/gsd-statusline.js#L107-L111
  gsd_update_display=""
  if [ -f ".claude/hooks/gsd-statusline.js" ] && echo "$input" | node .claude/hooks/gsd-statusline.js 2>/dev/null | grep -q "/gsd:update"; then
    gsd_update_display="${COLOR_YELLOW}/gsd:update${COLOR_RESET}"
  fi

  # empty segments are skipped by xargs
  printf '%s\n' \
    "$gsd_update_display" \
    "$vim_mode_display" \
    "$model_display" \
    "$total_tokens_display" \
    "$context_percentage_display" \
    "$syn_quota_display" \
    "$glm_quota_display" \
    "$copilot_quota_display" \
    "$version_display" \
    "$session_duration_display" \
    "$changes_display" | xargs
  exit 0
fi

echo "$input" | $(command -v bunx >/dev/null 2>&1 && echo "bunx" || echo "npx -y") ccstatusline@latest
