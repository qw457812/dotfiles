function o --wraps=open
    if set -q argv[1]
        open $argv
    else
        open .
    end
end
