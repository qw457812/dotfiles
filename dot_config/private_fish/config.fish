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
fish_add_path ~/go/bin

# Fish
set -g fish_greeting
set fish_emoji_width 2

set -gx TERM xterm-256color # https://github.com/gpakosz/.tmux
set -gx LANG "en_US.UTF-8"
set -gx LC_ALL "en_US.UTF-8"
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx EDITOR (which nvim)
set -gx VISUAL $EDITOR

# Exports
set -x LESS '--RAW-CONTROL-CHARS --ignore-case --LONG-PROMPT --chop-long-lines --incsearch --use-color --tabs=4 --intr=c$ --save-marks --status-line'
# set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x MANPAGER 'nvim -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
# set -x MANROFFOPT -c
set -x BAT_THEME TwoDark
set -x BAT_STYLE plain
set -x EZA_CONFIG_DIR "$HOME/.config/eza"

# Files & Directories
alias l 'eza --all --group-directories-first --color=always --color-scale all --icons=always --long --group --time-style=iso --git'
alias la 'eza --all --group-directories-first --color=always --color-scale all --icons=always --long --binary --group --header --modified --accessed --created --time-style=iso --git'
alias lm 'eza --all --sort=modified --color=always --color-scale all --icons=always --long --binary --group --header --modified --accessed --created --changed --time-style=iso --git'
alias lt 'eza --tree --level=2'
abbr f yazi
abbr ff vifm
abbr mv "mv -iv"
abbr cp "cp -riv"
abbr rm "rm -i"
abbr mkdir "mkdir -vp"
abbr ncdu "ncdu --color dark"
abbr pwdc "pwd | tr -d '\n' | fish_clipboard_copy"
abbr paths 'echo $PATH | tr " " "\n" | nl'
abbr dl "cd ~/Downloads"

# Editor & Pager
abbr vim nvim
abbr vi nvim
abbr v nvim
alias vimpager 'nvim - -c "lua require(\'util.terminal\').colorize()"'
alias cat 'bat --paging=never'
abbr -a --position anywhere --set-cursor -- -h "% -h 2>&1 | bat --plain --language=help"
abbr -a --position anywhere --set-cursor L "% | bat --style=plain --paging=always"
abbr -a --position anywhere --set-cursor LL "% 2>&1 | bat --style=plain --paging=always"
abbr -a --position anywhere --set-cursor V '% | nvim - -c "lua U.terminal.colorize()"'
abbr -a --position anywhere --set-cursor C "% | fish_clipboard_copy"
abbr -a --position anywhere --set-cursor F '% | fzf'
abbr -a --position anywhere --set-cursor W '% | wc -l'
abbr -a --position anywhere --set-cursor NE '% 2> /dev/null'
abbr -a --position anywhere --set-cursor NUL '% > /dev/null 2>&1'
abbr -a --position anywhere H '| head'
abbr -a --position anywhere T '| tail'
abbr -a --position anywhere G '| grep'
abbr -a --position anywhere J '| jq'

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
abbr ga "git add"
abbr gaa "git add --all"
abbr gcl "git clone --recurse-submodules"
abbr grv "git remote --verbose"
abbr glgp "git log --stat --patch"
abbr gprav "git pull --rebase --autostash -v"

# SVN
abbr sva 'svn add'
abbr svc 'svn commit'
abbr svs 'svn status'
abbr svu 'svn update'
abbr svl 'svn log -v'
abbr svll 'svn log -l'

# Chezmoi
abbr cz chezmoi
abbr czz 'cd (chezmoi source-path)' # chezmoi cd
abbr czs 'chezmoi status'
abbr cza 'chezmoi add'
abbr czd 'chezmoi diff'
abbr czap 'chezmoi apply'
abbr czapv 'chezmoi apply -v'
abbr cze 'chezmoi edit'
abbr czeap 'chezmoi edit --apply'
abbr czeapv 'chezmoi edit --apply --verbose'
abbr czu 'chezmoi update'
abbr czm 'chezmoi managed --path-style=absolute .'
abbr czum 'chezmoi unmanaged --path-style=absolute .'

# Homebrew
abbr bo 'brew update && brew outdated'
abbr bu 'brew upgrade'
abbr bi 'brew info'
abbr bI 'brew install'
abbr bl 'brew list | fzf'
abbr bs 'brew search'

# Fzf
# `--height 100%` is required, see https://github.com/wez/wezterm/discussions/4101
# --border --info=inline-right
set -x FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS 
  --height=100%
  --cycle
  --layout=reverse
  --ansi
  --scrollbar="▐"
  --ellipsis="…"
  --preview-window=border-left
  --bind=ctrl-j:down,ctrl-k:up
  --bind=ctrl-u:half-page-up,ctrl-d:half-page-down
  --bind=ctrl-s:jump
  --bind=ctrl-f:preview-half-page-down,ctrl-b:preview-half-page-up
  --bind=ctrl-a:beginning-of-line,ctrl-e:end-of-line
"
set fzf_diff_highlighter delta --paging=never --width=20
fzf_configure_bindings \
    --directory=\ct \
    --git_log=\cg \
    --git_status=\cs \
    --processes=\cp
# https://github.com/sxyazi/yazi/blob/shipped/yazi-plugin/preset/plugins/zoxide.lua
set -x _ZO_FZF_OPTS \
    "$FZF_DEFAULT_OPTS --keep-right --exit-0 --select-1" \
    "--preview='command eza --group-directories-first --color=always --icons=always {2..}'" \
    "--preview-window=down,30%,sharp"

# Other
abbr b "cd -"
abbr q exit
abbr reload "exec fish -l"
abbr fda "fd -IH"
abbr rga "rg -uu"
abbr show-cursor "tput cnorm"
abbr hide-cursor "tput civis"
abbr lzd lazydocker
abbr zj zellij
abbr py python3

set -g __proxy_ip "127.0.0.1"
set -g __http_proxy_port 7897
set -g __socks_proxy_port $__http_proxy_port
function term_proxy_on
    set -gx https_proxy "http://$__proxy_ip:$__http_proxy_port"
    set -gx http_proxy "http://$__proxy_ip:$__http_proxy_port"
    set -gx all_proxy "socks5://$__proxy_ip:$__socks_proxy_port"
end
function term_proxy_off
    set -e https_proxy
    set -e http_proxy
    set -e all_proxy
end
function sys_proxy_on
    networksetup -setwebproxy Wi-Fi $__proxy_ip $__http_proxy_port
    networksetup -setsecurewebproxy Wi-Fi $__proxy_ip $__http_proxy_port
    networksetup -setsocksfirewallproxy Wi-Fi $__proxy_ip $__socks_proxy_port
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
        set -Ux PYENV_ROOT $HOME/.pyenv
        fish_add_path $PYENV_ROOT/bin
        pyenv init - | source
        set -gx PYENV_VIRTUALENV_DISABLE_PROMPT 1
        pyenv virtualenv-init - | source
    end

    if set -q TERMUX_VERSION
        # https://github.com/sharkdp/bat/issues/1517
        function man --wraps='man'
            command man $argv | eval $MANPAGER
        end

        abbr pkgu 'pkg update && pkg upgrade'
        abbr pkgi 'pkg install'
        abbr pkgs 'pkg search'
        abbr pkgl 'pkg list-installed'
        abbr open termux-open
        alias l 'eza --all --group-directories-first --color=always --color-scale all --icons=always --long --time-style=iso --no-user --git'
        alias ll 'eza --all --group-directories-first --color=always --color-scale all --icons=always --long --group --time-style=iso --git'
        abbr dl 'cd ~/storage/downloads'
        abbr rime 'cd ~/storage/shared/Android/rime'
    else
        alias vless "nvim -u $(brew --prefix)/share/nvim/runtime/macros/less.vim"

        term_proxy_on
    end
end
