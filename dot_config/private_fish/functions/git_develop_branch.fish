# copied from: https://github.com/ohmyzsh/ohmyzsh/blob/55aa4c40e235cceb458689182e8e13f6cd99ca69/plugins/git/git.plugin.zsh#L19-L32
# Check for develop and similarly named branches
function git_develop_branch
    git rev-parse --git-dir &>/dev/null; or return

    for branch in dev devel develop development
        if git show-ref -q --verify refs/heads/$branch
            echo $branch
            return 0
        end
    end

    echo develop
    return 1
end
