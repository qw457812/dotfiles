function ta
    if test -z "$argv[1]" || test (string sub -l 1 -- "$argv[1]") = -
        tmux attach $argv
    else
        tmux attach -t $argv
    end
end
