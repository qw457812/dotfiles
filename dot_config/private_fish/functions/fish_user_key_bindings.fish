function __edit_command_buffer
    set -lx SHELL_COMMAND_EDITOR 1
    edit_command_buffer
end

# see `bind -p` for default bindings
function fish_user_key_bindings
    set -g fish_key_bindings fish_vi_key_bindings
    fish_default_key_bindings -M insert
    fish_vi_key_bindings --no-erase insert

    bind -M visual -m default y 'fish_clipboard_copy; commandline -f end-selection repaint-mode'
    bind yy fish_clipboard_copy
    if set -q TERMUX_VERSION
        # # https://github.com/fish-shell/fish-shell/issues/10807#issuecomment-2427887477
        # bind p 'set -g fish_cursor_end_mode exclusive' forward-char 'set -g fish_cursor_end_mode inclusive' 'commandline -i -- (termux-clipboard-get)'
        # bind P 'commandline -i -- (termux-clipboard-get)'
        #
        # https://github.com/fish-shell/fish-shell/blob/6f0532460a5be9c06fb15caa1f00e716ecef6420/share/functions/fish_clipboard_paste.fish#L26
        bind p 'set -g fish_cursor_end_mode exclusive' forward-char 'set -g fish_cursor_end_mode inclusive' '__fish_paste (termux-clipboard-get)'
        bind P '__fish_paste (termux-clipboard-get)'
    else
        bind p 'set -g fish_cursor_end_mode exclusive' forward-char 'set -g fish_cursor_end_mode inclusive' fish_clipboard_paste
        bind P fish_clipboard_paste
    end

    bind -M visual -m default v '__edit_command_buffer; commandline -f end-selection repaint-mode'
    bind -m visual V beginning-of-line begin-selection end-of-line repaint-mode
    bind -M visual V end-selection beginning-of-line begin-selection end-of-line

    bind U redo
    bind mm jump-to-matching-bracket
    bind -M visual mm jump-to-matching-bracket

    bind L end-of-line
    bind H beginning-of-line
    bind -M visual L end-of-line
    bind -M visual H beginning-of-line
    bind d,L kill-line
    bind d,H backward-kill-line
    bind -m insert c,L kill-line repaint-mode
    bind -m insert c,H backward-kill-line repaint-mode
    bind y,L kill-line yank
    bind y,H backward-kill-line yank

    # readline style bindings
    bind alt-k kill-line
    # ctrl-k was hijacked by tmux/kitty/wezterm for window navigation
    bind -M insert alt-k kill-line
    bind -M visual alt-k kill-line

    # ctrl-l was hijacked by tmux/kitty/wezterm for window navigation
    # bind alt-l clear-screen
    # bind -M insert alt-l clear-screen
    # bind -M visual alt-l clear-screen
    bind alt-l c repaint-mode
    bind -M insert alt-l c repaint-mode
    bind -M visual alt-l c repaint-mode
end
