function mkd --wraps=mkdir
    mkdir -p $argv && cd $argv[-1]
end
