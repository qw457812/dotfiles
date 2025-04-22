function psgrep --wraps=grep
    ps aux | grep -v grep | grep $argv
end
