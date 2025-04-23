# https://www.toptal.com/developers/gitignore
# https://docs.gitignore.io/install/command-line
function gitignore
    set -l templates (string join "," $argv)
    curl -sL https://www.toptal.com/developers/gitignore/api/$templates >>.gitignore
end

# https://docs.gitignore.io/use/advanced-command-line#zubin
function __complete_gitignore
    if ! set -q __COMPLETE_GITIGNORE
        set -g __COMPLETE_GITIGNORE (curl -sL https://www.toptal.com/developers/gitignore/api/list)
    end
    # echo $__COMPLETE_GITIGNORE | tr "," "\n" | tr " " "\n"
    string split "," $__COMPLETE_GITIGNORE | string trim
end

complete -c gitignore -f -a '(__complete_gitignore)'
