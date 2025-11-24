function git_fixup_rebase --wraps='git commit --fixup'
    set -l commit $argv[1]

    if test -z "$commit"
        echo "Usage: git_fixup_rebase <commit>"
        return 1
    end

    # add `GIT_SEQUENCE_EDITOR=:` to skip the interactive editing step
    git commit --fixup "$commit" && GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "$commit~1"
end
