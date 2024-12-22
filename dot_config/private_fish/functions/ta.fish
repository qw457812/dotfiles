function ta
    if test -z "$argv[1]" || test (string sub -l 1 -- "$argv[1]") = -
        tmux attach $argv
    else
        tmux attach -t $argv
    end
end

function __complete_ta
    tmux list-sessions -F '#S' 2>/dev/null
end

complete -c ta -f -a "(__complete_ta)"
