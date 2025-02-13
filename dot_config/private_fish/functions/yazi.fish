# https://yazi-rs.github.io/docs/quick-start/#shell-wrapper
function yazi --wraps=yazi
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    command yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        cd -- "$cwd" # using `cd` instead of `builtin cd` to maintain `cd -` functionality
    end
    rm -f -- "$tmp"
end
