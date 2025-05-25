# respect .gitignore
if type -q fd
    set -x FZF_DEFAULT_COMMAND "fd --type f --type l --hidden --follow"
else if type -q rg
    set -x FZF_DEFAULT_COMMAND "rg --files --hidden --follow"
end

# `--height 100%` is required, see https://github.com/wez/wezterm/discussions/4101
# https://github.com/folke/tokyonight.nvim/blob/45d22cf0e1b93476d3b6d362d720412b3d34465c/extras/fzf/tokyonight_moon.sh
set -x FZF_DEFAULT_OPTS "
  --height=100%
  --tmux=100%
  --cycle
  --layout=reverse
  --ansi
  --scrollbar="▐"
  --ellipsis="…"
  --preview-window=border-left
  --bind=ctrl-j:down,ctrl-k:up
  --bind=ctrl-u:half-page-up,ctrl-d:half-page-down
  --bind=ctrl-s:jump
  --bind=ctrl-f:preview-half-page-down,ctrl-b:preview-half-page-up
  --bind=ctrl-a:beginning-of-line,ctrl-e:end-of-line
  --bind=ctrl-r:toggle-all
  --highlight-line
  --info=inline-right
  --border=none
  --color=border:#589ed7
  --color=gutter:#1e2030
  --color=header:#ff966c
  --color=marker:#ff007c
  --color=pointer:#ff007c
  --color=prompt:#65bcff
  --color=query:#c8d3f5:regular
  --color=scrollbar:#589ed7
  --color=separator:#ff966c
  --color=spinner:#ff007c
"

# https://github.com/PatrickF1/fzf.fish
set fzf_diff_highlighter delta --paging=never --width=20
set fzf_history_opts --preview-window=border-rounded
set fzf_processes_opts --preview-window=border-rounded
fzf_configure_bindings \
    --directory=\ct \
    --git_log=\cg \
    --git_status=\cs \
    --processes=\cp

# https://github.com/sxyazi/yazi/blob/46125eda6e7ca4c5c91ecf933b5409cca232dd1c/yazi-plugin/preset/plugins/zoxide.lua
set -x _ZO_FZF_OPTS \
    "$FZF_DEFAULT_OPTS --keep-right --exit-0 --select-1" \
    "--preview='command eza --group-directories-first --color=always --icons=always {2..}'" \
    "--preview-window=down,30%,border-rounded"
