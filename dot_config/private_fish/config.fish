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
set -x TERM xterm-256color # https://github.com/gpakosz/.tmux
set -x LESS '--RAW-CONTROL-CHARS --ignore-case --LONG-PROMPT --chop-long-lines --incsearch --use-color --tabs=4 --intr=c$ --save-marks --status-line'
# set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x MANPAGER 'nvim -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
# set -x MANROFFOPT -c
set -x BAT_THEME TwoDark
set -x BAT_STYLE plain
set -x EZA_CONFIG_DIR "$HOME/.config/eza"

abbr b "cd -"
abbr q exit

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
abbr bl 'brew list | fzf'
abbr bs 'brew services'
abbr bS 'brew search'

# Fzf
# `--height 100%` is required, see https://github.com/wez/wezterm/discussions/4101
# --cycle
set -x FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS 
  --height=100%
  --layout=reverse
  --ansi
  --scrollbar="▐"
  --preview-window=border-left
  --bind=ctrl-j:down,ctrl-k:up
  --bind=ctrl-f:page-down,ctrl-b:page-up
  --bind=ctrl-s:jump
  --bind=ctrl-u:preview-page-up,ctrl-d:preview-page-down
  --bind=ctrl-a:beginning-of-line,ctrl-e:end-of-line
"
set fzf_diff_highlighter delta --paging=never --width=20
fzf_configure_bindings \
    --directory=\ct \
    --git_log=\cg \
    --git_status=\cs \
    --processes=\cp

# Other
abbr fda "fd -IH"
abbr rga "rg -uu"
abbr show-cursor "tput cnorm"
abbr hide-cursor "tput civis"
abbr lzd lazydocker
abbr py python3

# reload network
function newloc
    set -l old (networksetup -getcurrentlocation)
    set -l new "tmp_"(date '+%Y%m%d_%H%M%S')
    if networksetup -createlocation $new populate >/dev/null; and networksetup -switchtolocation $new >/dev/null; and string match -q "tmp_*" $old
        networksetup -deletelocation $old >/dev/null
    end
end

set -g proxy_ip "127.0.0.1"
set -g http_proxy_port 7897
set -g socks_proxy_port 7897
function term_proxy_on
    set -gx https_proxy "http://$proxy_ip:$http_proxy_port"
    set -gx http_proxy "http://$proxy_ip:$http_proxy_port"
    set -gx all_proxy "socks5://$proxy_ip:$socks_proxy_port"
end
function term_proxy_off
    set -e https_proxy
    set -e http_proxy
    set -e all_proxy
end
function sys_proxy_on
    networksetup -setwebproxy Wi-Fi $proxy_ip $http_proxy_port
    networksetup -setsecurewebproxy Wi-Fi $proxy_ip $http_proxy_port
    networksetup -setsocksfirewallproxy Wi-Fi $proxy_ip $socks_proxy_port
    networksetup -setwebproxystate Wi-Fi on
    networksetup -setsecurewebproxystate Wi-Fi on
    networksetup -setsocksfirewallproxystate Wi-Fi on
end
function sys_proxy_off
    networksetup -setwebproxystate Wi-Fi off
    networksetup -setsecurewebproxystate Wi-Fi off
    networksetup -setsocksfirewallproxystate Wi-Fi off
end

if status is-interactive
    if type -q atuin
        set -gx ATUIN_NOBIND true
        atuin init fish | source
    end

    # set -x LESSOPEN "|/opt/homebrew/bin/lesspipe.sh %s"
    if type -q batpipe
        eval (batpipe)
    end

    if type -q pyenv
        pyenv init - | source
        set -gx PYENV_VIRTUALENV_DISABLE_PROMPT 1
        pyenv virtualenv-init - | source
    end

    term_proxy_on
end
