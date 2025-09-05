# copied from: https://github.com/ohmyzsh/ohmyzsh/blob/b9c9fcfd3fb93c43b456ddb608308c9ac9bffab1/plugins/git/git.plugin.zsh#L35-L58
# Get the default branch name from common branch names or fallback to remote HEAD
function git_main_branch
    command git rev-parse --git-dir &>/dev/null || return

    set -l remote ref

    for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}
        if command git show-ref -q --verify $ref
            echo (basename $ref)
            return 0
        end
    end

    # Fallback: try to get the default branch from remote HEAD symbolic refs
    for remote in origin upstream
        set ref (command git rev-parse --abbrev-ref $remote/HEAD 2>/dev/null)
        if string match -q "$remote/*" $ref
            echo (string replace "$remote/" "" $ref)
            return 0
        end
    end

    # If no main branch was found, fall back to master but return error
    echo master
    return 1
end
