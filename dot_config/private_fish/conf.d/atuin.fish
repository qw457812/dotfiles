if test -f "$HOME/.atuin/bin/env.fish"
    source "$HOME/.atuin/bin/env.fish"
end

status is-interactive; or exit

if type -q atuin
    set -gx ATUIN_NOBIND true
    atuin init fish | source
end
