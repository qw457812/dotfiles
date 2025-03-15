function __edit_command_buffer
    set -lx SHELL_COMMAND_EDITOR 1
    edit_command_buffer
end

function fish_user_key_bindings
    set -g fish_key_bindings fish_vi_key_bindings
    fish_default_key_bindings -M insert
    fish_vi_key_bindings --no-erase insert

    bind -M visual -m default y 'fish_clipboard_copy; commandline -f end-selection repaint-mode'
    bind yy fish_clipboard_copy
    bind p 'set -g fish_cursor_end_mode exclusive' forward-char 'set -g fish_cursor_end_mode inclusive' fish_clipboard_paste
    bind P fish_clipboard_paste

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

    # TODO: https://github.com/fish-shell/fish-shell/issues/10807#issuecomment-2427887477
end
