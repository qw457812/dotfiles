if set -q TERMUX_VERSION
    # https://github.com/sharkdp/bat/issues/1517
    function man --wraps=man
        command man $argv | eval $MANPAGER
    end
end
