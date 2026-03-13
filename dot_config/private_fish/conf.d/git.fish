# TODO: https://github.com/max-sixty/worktrunk

# copied from: https://github.com/folke/dot/commit/3fe0fd9
set -g git_worktrees_root ~/projects/git-worktrees
mkdir -p $git_worktrees_root

function gw -a name
    if test -z "$name"
        gwm # switch to main or latest worktree
        return 0
    end

    set -l repo (basename (git worktree list | head -n 1 | awk '{print $1}'))
    set -l path $git_worktrees_root/"$repo-"(string replace -a '/' '-' -- $name)

    if not test -d $path
        set -l remote_branch origin/$name
        if not git show-ref --verify --quiet refs/remotes/$remote_branch
            set remote_branch (git for-each-ref --format='%(refname:short)' "refs/remotes/*/$name" | head -n 1)
        end
        if git show-ref --verify --quiet refs/heads/$name
            git worktree add $path $name || return 1
        else if test -n "$remote_branch"
            git worktree add --track -b $name $path $remote_branch || return 1
        else
            git worktree add $path -b $name || return 1
        end
        echo "Created worktree '$name' at $path"
    end
    cd $path
end

function gpr -a pr
    if test -z "$pr"
        echo "Usage: gpr <pr-number-or-branch>"
        return 1
    end

    set -l branch (gh pr view "$pr" --json headRefName -q .headRefName)
    set -l repo (basename (git worktree list | head -n 1 | awk '{print $1}'))
    set -l path $git_worktrees_root/"$repo-$pr-"(string replace -a '/' '-' -- $branch)

    if not test -d $path
        git worktree add $path || return 1
        cd $path # needed for gh to work correctly
        gh pr checkout $pr || return 1
    end
    cd $path # switch to the worktree
end

function gwl
    set -l current (git rev-parse --show-toplevel 2>/dev/null; or pwd)
    set -l worktrees (git worktree list)
    set -l filtered
    for wt in $worktrees
        if test (echo $wt | awk '{print $1}') != "$current"
            set -a filtered $wt
        end
    end
    if test (count $filtered) -eq 0
        return 0
    end
    set -l selected (printf '%s\n' $filtered | fzf)
    if test -n "$selected"
        cd (echo $selected | awk '{print $1}')
    end
end

function gwr
    set -l candidates (git worktree list | tail -n +2)
    if test (count $candidates) -eq 0
        return 0
    end
    set -l selected (printf '%s\n' $candidates | fzf | awk '{print $1}')
    if test -n "$selected"
        set -l main (git worktree list | head -n 1 | awk '{print $1}')
        cd $main
        git worktree remove $selected
    end
end

function gwm
    set -l current (git rev-parse --show-toplevel 2>/dev/null; or pwd)
    set -l main (git worktree list | head -n 1 | awk '{print $1}')

    if test "$current" = "$main"
        # We're in main, go to most recent worktree
        set -l latest (git worktree list | tail -n 1 | awk '{print $1}')
        if test "$latest" != "$main"
            cd $latest
        end
    else
        # We're in a worktree, go to main
        cd $main
    end
end
