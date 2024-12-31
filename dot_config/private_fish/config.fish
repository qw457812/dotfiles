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
fish_add_path /opt/homebrew/opt/rustup/bin
fish_add_path ~/.local/bin
fish_add_path ~/go/bin
fish_add_path "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"

# Fish
set -g fish_greeting
set fish_emoji_width 2

set -gx TERM xterm-256color # https://github.com/gpakosz/.tmux
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx LC_CTYPE en_US.UTF-8
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx EDITOR (which nvim)
set -gx VISUAL $EDITOR

set -g __proxy_ip "127.0.0.1"
set -g __http_proxy_port 7897
set -g __socks_proxy_port $__http_proxy_port

# Exports
set -x LESS '--RAW-CONTROL-CHARS --ignore-case --LONG-PROMPT --chop-long-lines --incsearch --use-color --tabs=4 --intr=c$ --save-marks --status-line'
# set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x MANPAGER 'nvim -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
# set -x MANROFFOPT -c
set -x BAT_THEME TwoDark
set -x BAT_STYLE plain
set -x EZA_CONFIG_DIR "$HOME/.config/eza"
set -x EZA_MIN_LUMINANCE 50

# Fzf
# `--height 100%` is required, see https://github.com/wez/wezterm/discussions/4101
# https://github.com/folke/tokyonight.nvim/blob/45d22cf0e1b93476d3b6d362d720412b3d34465c/extras/fzf/tokyonight_moon.sh
set -x FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS 
  --height=100%
  --tmux=100%
  --cycle
  --layout=reverse
  --ansi
  --scrollbar="▐"
  --ellipsis="…"
  --preview-window=border-left
  --bind=ctrl-j:down,ctrl-k:up
  --bind=ctrl-f:page-down,ctrl-b:page-up
  --bind=ctrl-s:jump
  --bind=ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down
  --bind=ctrl-a:beginning-of-line,ctrl-e:end-of-line
  --highlight-line
  --info=inline-right
  --border=none
  --color=border:#589ed7
  --color=gutter:#1e2030
  --color=header:#ff966c
  --color=marker:#ff007c
  --color=pointer:#ff007c
  --color=prompt:#65bcff
  --color=query:#c8d3f5:regular
  --color=scrollbar:#589ed7
  --color=separator:#ff966c
  --color=spinner:#ff007c
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

# Files & Directories
set -l ll_cmd 'eza --all --color=always --color-scale all --icons=always --long --group --time-style=iso --git'
alias ll "$ll_cmd --group-directories-first"
alias lm "$ll_cmd --sort=modified --classify --header --modified --created"
alias lt 'eza --tree --level=2'
alias l ll
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
        abbr pkgu 'pkg update && pkg upgrade'
        abbr pkgi 'pkg install'
        abbr pkgs 'pkg search'
        abbr pkgl 'pkg list-installed'
        abbr open termux-open
        alias l 'eza --all --group-directories-first --color=always --color-scale all --icons=always --long --time-style=iso --git --no-user'
        abbr dl 'cd ~/storage/downloads'
        abbr rime 'cd ~/storage/shared/Android/rime'

        if not set -q TMUX
            tmux attach || tmux
        end
    else
        alias vless "nvim -u $(brew --prefix)/share/nvim/runtime/macros/less.vim"

        term_proxy_on
    end
end
