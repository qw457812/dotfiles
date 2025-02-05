function fish_user_key_bindings
    set -g fish_key_bindings fish_vi_key_bindings
    fish_default_key_bindings -M insert
    fish_vi_key_bindings --no-erase insert
    bind -M visual -m default y 'fish_clipboard_copy; commandline -f end-selection repaint-mode'
    bind yy fish_clipboard_copy
    bind p fish_clipboard_paste
    bind -M visual -m default v 'edit_command_buffer; commandline -f end-selection repaint-mode'
    bind L end-of-line
    bind H beginning-of-line
    bind -M visual L end-of-line
    bind -M visual H beginning-of-line
    bind -m visual V beginning-of-line begin-selection end-of-line repaint-mode
    bind -M visual V end-selection beginning-of-line begin-selection end-of-line
    # TODO: https://github.com/fish-shell/fish-shell/issues/10807#issuecomment-2427887477
end
