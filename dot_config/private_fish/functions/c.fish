function c
    clear
    if set -q TMUX
        command tmux clear-history
    end
end
