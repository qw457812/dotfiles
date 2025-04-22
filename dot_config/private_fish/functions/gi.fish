# https://www.toptal.com/developers/gitignore
# https://docs.gitignore.io/install/command-line
function gi
    curl -sL https://www.toptal.com/developers/gitignore/api/$argv
end

# https://docs.gitignore.io/use/advanced-command-line#zubin
function __complete_gi
    if ! set -q __COMPLETE_GI
        set -g __COMPLETE_GI (curl -sL https://www.toptal.com/developers/gitignore/api/list)
    end
    # echo $__COMPLETE_GI | tr "," "\n" | tr " " "\n"
    string split "," $__COMPLETE_GI | string trim
end

complete -c gi -f -a '(__complete_gi)'
