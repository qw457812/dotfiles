function c
    clear
    if set -q TMUX
        command tmux clear-history
    end
    if set -q KITTY_PID
        # clear-screen-and-scrollback | https://github.com/kovidgoyal/kitty/blob/c1a987353037837c1a80234ce3d07335d48931a8/kitty/options/definition.py#L4345-L4347
        printf "\e[H\e[3J"
    end
end
