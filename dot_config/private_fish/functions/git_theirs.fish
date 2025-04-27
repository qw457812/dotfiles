# function git_theirs
#     git checkout --theirs $argv; and git add $argv
# end

# copied from: https://github.com/KyleMcB/dotfiles/blob/ccee8869b024cac0056852c3127a708b27dad5c9/stow/fish/.config/fish/functions/git_theirs.fish
function git_theirs
    # Get the list of conflicted files
    set conflicts (git diff --name-only --diff-filter=U)

    # Exit if no conflicts are found
    if test (count $conflicts) -eq 0
        echo "No conflicted files found."
        return
    end

    # Use fzf to select files (multi-select mode with Tab)
    set selected_files (printf '%s\n' $conflicts | fzf --multi --preview "git diff --color=always -- {}")

    # Exit if no files are selected
    if test -z "$selected_files"
        echo "No files selected."
        return
    end

    # Iterate over selected files and perform the operation
    for file in $selected_files
        git checkout --theirs $file
        echo "Accepted incoming version for: $file"
        git add $file
    end

    echo "Resolved and staged files:"
    echo $selected_files
end
