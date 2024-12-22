set -x _ZO_FZF_OPTS \
    "$FZF_DEFAULT_OPTS --keep-right --exit-0 --select-1" \
    "--preview='command eza --group-directories-first --color=always --icons=always {2..}'" \
    "--preview-window=down,30%,sharp"
zoxide init fish | source
