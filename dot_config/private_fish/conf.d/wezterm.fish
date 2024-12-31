# https://github.com/wez/wezterm/blob/6f375e29a2c4d70b8b51956edd494693196c6692/assets/shell-integration/wezterm.sh

# This file hooks up shell integration for wezterm.
#
# Although wezterm is mentioned here, the sequences used are not wezterm
# specific and may provide the same functionality for other terminals.  Most
# terminals are good at ignoring OSC sequences that they don't understand, but
# if not there are some bypasses:
#
# WEZTERM_SHELL_SKIP_ALL - disables all
# WEZTERM_SHELL_SKIP_SEMANTIC_ZONES - disables zones
# WEZTERM_SHELL_SKIP_CWD - disables OSC 7 cwd setting
# WEZTERM_SHELL_SKIP_USER_VARS - disable user vars that capture information
#                                about running programs

if not set -q WEZTERM_UNIX_SOCKET
    exit
end

if test "$WEZTERM_SHELL_SKIP_ALL" = 1
    exit
end

if not status is-interactive
    exit
end

switch "$TERM"
    case linux dumb
        # Avoid terminals that don't like OSC sequences
        exit
end

# This function emits an OSC 1337 sequence to set a user var
# associated with the current terminal pane.
# It requires the `base64` utility to be available in the path.
function __wezterm_set_user_var
    if hash base64 2>/dev/null
        if test -z "$TMUX"
            printf "\033]1337;SetUserVar=%s=%s\007" "$argv[1]" (echo -n "$argv[2]" | base64)
        else
            # <https://github.com/tmux/tmux/wiki/FAQ#what-is-the-passthrough-escape-sequence-and-how-do-i-use-it>
            # Note that you ALSO need to add "set -g allow-passthrough on" to your tmux.conf
            printf "\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\" "$argv[1]" (echo -n "$argv[2]" | base64)
        end
    end
end

if test -z "$WEZTERM_SHELL_SKIP_USER_VARS"
    function __wezterm_user_vars_precmd --on-event fish_prompt
        # __wezterm_set_user_var WEZTERM_PROG ""
        # __wezterm_set_user_var WEZTERM_USER (id -un)

        # Indicate whether this pane is running inside tmux or not
        if test -n "$TMUX"
            __wezterm_set_user_var WEZTERM_IN_TMUX 1
        else
            __wezterm_set_user_var WEZTERM_IN_TMUX 0
        end

        # # You may set WEZTERM_HOSTNAME to a name you want to use instead
        # # of calling out to the hostname executable on every prompt print.
        # if test -z "$WEZTERM_HOSTNAME"
        #     if hash hostname 2>/dev/null
        #         __wezterm_set_user_var WEZTERM_HOST (hostname)
        #     else if hash hostnamectl 2>/dev/null
        #         __wezterm_set_user_var WEZTERM_HOST (hostnamectl hostname)
        #     end
        # else
        #     __wezterm_set_user_var WEZTERM_HOST "$WEZTERM_HOSTNAME"
        # end
    end

    # function __wezterm_user_vars_preexec --on-event fish_preexec
    #     # Tell wezterm the full command that is being run
    #     __wezterm_set_user_var WEZTERM_PROG "$argv[1]"
    # end
end
