# copied from: https://github.com/ohmyzsh/ohmyzsh/blob/750d3ac4b493dca13ef0ced55fa6a2cd02dc7ee8/plugins/git/git.plugin.zsh#L35-L48
# Check if main exists and use instead of master
function git_main_branch
    command git rev-parse --git-dir &>/dev/null || return
    set -l ref
    for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}
        if command git show-ref -q --verify $ref
            echo (basename $ref)
            return 0
        end
    end

    # If no main branch was found, fall back to master but return error
    echo master
    return 1
end
