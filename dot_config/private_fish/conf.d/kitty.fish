if not set -q KITTY_PID
    exit
end

if not status is-interactive
    exit
end

function __kitty_set_user_var
    if test -z "$TMUX"
        printf "\033]1337;SetUserVar=%s=%s\007" "$argv[1]" (echo -n "$argv[2]" | base64)
    else
        printf "\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\" "$argv[1]" (echo -n "$argv[2]" | base64)
    end
end

function __kitty_unset_user_var
    if test -z "$TMUX"
        printf "\033]1337;SetUserVar=%s\007" "$argv[1]"
    else
        printf "\033Ptmux;\033\033]1337;SetUserVar=%s\007\033\\" "$argv[1]"
    end
end

function __kitty_user_vars_precmd --on-event fish_prompt
    if test -n "$TMUX"
        __kitty_set_user_var KITTY_IN_TMUX 1
    else
        __kitty_unset_user_var KITTY_IN_TMUX
    end
end
