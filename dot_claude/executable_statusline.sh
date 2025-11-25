#!/bin/sh

input=$(cat)
# echo "$input" >/tmp/statusline_debug.json
# cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# fixes https://github.com/anthropics/claude-code/issues/10375
if [ -n "$TMUX" ]; then
  printf '\ePtmux;\e\e[?1004l\e\\'
else
  printf '\e[?1004l'
fi

if [ "$__IS_CLAUDECODE_NVIM" = "1" ] || [ -n "$TERMUX_VERSION" ]; then
  transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

  total_tokens=$(cat "$transcript_path" 2>/dev/null | jq -s '
    [.[] | select(.type == "assistant") | .message.usage] | last |
    (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)
  ' || echo 0)

  # context
  awk -v t="$total_tokens" 'BEGIN {printf "%.1fk %.1f%%\n", t/1000, t*100/200000}'
  exit 0
fi

# # TODO: add to ccstatusline
# if command -v starship >/dev/null 2>&1; then
#   # https://github.com/Rolv-Apneseth/starship.yazi/blob/a63550b2f91f0553cc545fd8081a03810bc41bc0/main.lua#L111-L126
#   # STARSHIP_SHELL="" starship prompt | grep -m1 .
#   STARSHIP_CONFIG="$HOME/.config/starship-statusline.toml" STARSHIP_SHELL="" starship prompt
# fi

if command -v bunx >/dev/null 2>&1; then
  echo "$input" | bunx -y ccstatusline@latest
else
  echo "$input" | npx -y ccstatusline@latest
fi
