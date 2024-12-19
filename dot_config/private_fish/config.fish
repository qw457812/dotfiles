if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Cursor styles
set -gx fish_vi_force_cursor 1
set -gx fish_cursor_default block
set -gx fish_cursor_insert line blink
set -gx fish_cursor_visual block
set -gx fish_cursor_replace_one underscore

# Path
set -x fish_user_paths
fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin
fish_add_path ~/.local/bin

set -g fish_greeting

set -gx EDITOR (which nvim)
set -gx VISUAL $EDITOR

# Exports
# https://github.com/gpakosz/.tmux
set -x TERM xterm-256color
set -x LESS '--RAW-CONTROL-CHARS --ignore-case --LONG-PROMPT --chop-long-lines --incsearch --use-color --tabs=4 --intr=c$ --save-marks --status-line'
# set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x MANPAGER 'nvim -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
# set -x MANROFFOPT -c
set -x BAT_THEME TwoDark
set -x BAT_STYLE plain
set -x EZA_CONFIG_DIR "$HOME/.config/eza"

abbr b "cd -"
abbr q exit
function c
    clear
    if set -q TMUX
        command tmux clear-history
    end
end

# Files & Directories
alias l 'eza --all --group-directories-first --color=always --color-scale all --icons=auto --long --group --time-style=iso --git'
alias la 'eza --all --group-directories-first --color=always --color-scale all --icons=auto --long --binary --group --header --modified --accessed --created --time-style=iso --git'
alias lm 'eza --all --sort=modified --color=always --color-scale all --icons=auto --long --binary --group --header --modified --accessed --created --changed --time-style=iso --git'
alias lt 'eza --tree --level=2'
abbr mv "mv -iv"
abbr cp "cp -riv"
abbr rm "rm -i"
abbr mkdir "mkdir -vp"
abbr pwdc "pwd | tr -d '\n' | pbcopy"
abbr ncdu "ncdu --color dark"
abbr dl "cd ~/Downloads"
abbr ... 'cd ../..'
abbr .... 'cd ../../..'
abbr ..... 'cd ../../../..'
function mkd
    mkdir -p $argv && cd $argv[-1]
end
function cdf
    cd (osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')
end
function o
    if test (count $argv) -eq 0
        open .
    else
        open $argv
    end
end

# Editor
abbr vim nvim
abbr vi nvim
abbr v nvim
alias vimpager 'nvim - -c "lua require(\'util.terminal\').colorize()"'

# Bat
alias cat 'bat --paging=never'
abbr -a --position anywhere --set-cursor -- -h "-h 2>&1 | bat --plain --language=help"

abbr -a --position anywhere H '| head'
abbr -a --position anywhere T '| tail'
abbr -a --position anywhere G '| grep'
abbr -a --position anywhere L "| bat --style=plain --paging=always"
abbr -a --position anywhere LL "2>&1 | bat --style=plain --paging=always"
abbr -a --position anywhere C "| clipcopy"
abbr -a --position anywhere F '| fzf'
abbr -a --position anywhere V '| nvim - -c "lua U.terminal.colorize()"'
abbr -a --position anywhere J '| jq'
abbr -a --position anywhere W '| wc -l'

# Tmux
abbr t tmux
abbr tc 'tmux attach'
abbr ta 'tmux attach -t'
abbr tad 'tmux attach -d -t'
abbr ts 'tmux new -s'
abbr tl 'tmux ls'
abbr tk 'tmux kill-session -t'

# Git
abbr g git
abbr gg lazygit
abbr gl 'git l --color'
abbr gs "git st"
abbr gb "git checkout -b"
abbr gc "git commit --verbose"
# abbr gpr "hub pr checkout"
abbr gd "git diff"
abbr gds "git diff --staged"
abbr gm "git branch -l main | rg main > /dev/null 2>&1 && git checkout main || git checkout master"
abbr gcp "git commit -p"
abbr gpp "git push"
abbr gp "git pull"
abbr gcl "git clone --recurse-submodules"
abbr grv "git remote --verbose"

# SVN
abbr sva 'svn add'
abbr svc 'svn commit'
abbr svs 'svn status'
abbr svu 'svn update'
abbr svl 'svn log -v'
function svd
    svn diff -x -p $argv | svn_strip_diff_header | delta --line-numbers
end
function svld
    svn log -v --diff $argv | svn_strip_diff_header | delta --line-numbers
end
function svldr
    svn log -v --diff -r $argv | svn_strip_diff_header | delta --line-numbers
end

# Chezmoi
abbr cz chezmoi
abbr cze 'chezmoi edit'
abbr czd 'chezmoi diff'
abbr czs 'chezmoi status'
abbr cza 'chezmoi -v apply'
abbr czea 'chezmoi edit --apply --verbose'
# abbr czz 'chezmoi cd'
abbr czz 'cd ~/.local/share/chezmoi'
abbr czm 'chezmoi managed .'
abbr czum 'chezmoi unmanaged .'

# Homebrew
abbr bo 'brew update && brew outdated'
abbr bu 'brew upgrade'
abbr bi 'brew info'
abbr bI 'brew install'
abbr bl 'brew list'
abbr bs 'brew services'
abbr bsr 'brew services restart'
abbr bsk 'brew services kill'
abbr bS 'brew search'
abbr bd 'brew doctor'

# Other
abbr fda "fd -IH"
abbr rga "rg -uu"
abbr show-cursor "tput cnorm"
abbr hide-cursor "tput civis"
abbr lzd lazydocker
abbr py python3

# # brew info lesspipe
# set -x LESSOPEN "|/opt/homebrew/bin/lesspipe.sh %s"
# https://github.com/eth-p/bat-extras/blob/master/doc/batpipe.md#usage
eval (batpipe)

fzf --fish | source

pyenv init - | source

set -gx ATUIN_NOBIND true
atuin init fish | source
