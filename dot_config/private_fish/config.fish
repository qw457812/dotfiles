# Cursor styles
set -gx fish_vi_force_cursor 1
set -gx fish_cursor_default block
set -gx fish_cursor_insert line blink
set -gx fish_cursor_visual block
set -gx fish_cursor_replace_one underscore

# Path
set -x fish_user_paths
fish_add_path ~/go/bin
set -q TERMUX_VERSION; or fish_add_path ~/.cargo/bin # https://github.com/rust-lang/rustup/blob/5e59246c45756b860ffa2c0e471e9989f0d56ff8/doc/user-guide/src/installation/already-installed-rust.md?plain=1#L63-L66
fish_add_path ~/.local/share/bob/nvim-bin
fish_add_path ~/.local/bin
fish_add_path "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
fish_add_path "$HOME/Library/Application Support/Coursier/bin" # scalafmt
fish_add_path ~/.codeium/windsurf/bin

# Fish
set -g fish_greeting
set fish_emoji_width 2
alias ssh "TERM=xterm-256color command ssh"
alias mosh "TERM=xterm-256color command mosh"

# set -gx TERM xterm-256color # https://github.com/gpakosz/.tmux
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx LC_CTYPE en_US.UTF-8
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx EDITOR (which nvim)
set -gx VISUAL $EDITOR
set -gx SUDO_EDITOR $EDITOR

set -g __proxy_ip "127.0.0.1"
set -g __http_proxy_port 10808
set -g __socks_proxy_port $__http_proxy_port

# Exports
set -x LESS '--RAW-CONTROL-CHARS --ignore-case --LONG-PROMPT --chop-long-lines --incsearch --use-color --tabs=4 --intr=c$ --save-marks --status-line'
if status is-interactive # https://github.com/ndonfris/fish-lsp/blob/1be77fcfa37d9d3877994f14163c7faacf7a533e/fish_files/get-documentation.fish
    # set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -x MANPAGER 'nvim --cmd "lua vim.g.manpager = true" -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
end
# set -x MANROFFOPT -c
set -x EZA_MIN_LUMINANCE 50
set -x DYLD_LIBRARY_PATH /opt/homebrew/opt/librime/lib # https://github.com/wlh320/rime-ls#macos
set -x RIPGREP_CONFIG_PATH $HOME/.ripgreprc
set -x LG_CONFIG_FILE $HOME/.config/lazygit/config.yml,$HOME/.cache/nvim/lazygit-theme.yml

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
alias vimpager 'nvim - --cmd "lua vim.g.pager = true" -c "lua require(\'util.terminal\').colorize()"'
alias cat 'bat --paging=never'
abbr -a --position anywhere --set-cursor -- -h "% -h 2>&1 | bat --plain --language=help"
abbr -a --position anywhere --set-cursor L "% | bat --style=plain --paging=always"
abbr -a --position anywhere --set-cursor LL "% 2>&1 | bat --style=plain --paging=always"
abbr -a --position anywhere --set-cursor V '% | vimpager'
abbr -a --position anywhere --set-cursor VV '% 2>&1 | vimpager'
abbr -a --position anywhere --set-cursor C "% | fish_clipboard_copy"
abbr -a --position anywhere --set-cursor F '% | fzf'
abbr -a --position anywhere --set-cursor W '% | wc -l'
abbr -a --position anywhere --set-cursor NE '% 2> /dev/null'
abbr -a --position anywhere --set-cursor NUL '% > /dev/null 2>&1'
abbr -a --position anywhere H '| head'
abbr -a --position anywhere T '| tail'
abbr -a --position anywhere G '| grep'
abbr -a --position anywhere R '| rg'
abbr -a --position anywhere J '| jq'
abbr -a --position anywhere D '| delta'

# Tmux
alias tmux "TERM=xterm-256color command tmux" # https://github.com/gpakosz/.tmux
abbr t tmux
abbr tad 'tmux attach -d -t'
abbr ts 'tmux new -s'
abbr tl 'tmux ls'
abbr tk 'tmux kill-session -t'
abbr tksv 'tmux kill-server'

# Git
abbr g git
alias lazygit "TERM=xterm-256color command lazygit"
alias glab "env -u https_proxy -u http_proxy -u all_proxy command glab"
abbr gg lazygit
abbr gl 'git l --color'
abbr gs "git status"
abbr gp "git pull"
abbr gpp "git push"
# abbr gcp "git commit -p"
# abbr gpr "hub pr checkout"
# abbr gcm "git branch -l main | rg main > /dev/null 2>&1 && git checkout main || git checkout master"
# abbr gdw "git diff --word-diff"
abbr gdw "git diff --ignore-all-space"
abbr gdsw "git diff --staged --ignore-all-space"
abbr glgpw "git log --stat --patch --ignore-all-space"
abbr gdm 'git diff (git_main_branch)'
abbr gdom 'git diff origin/(git_main_branch)'
abbr gdum 'git diff upstream/(git_main_branch)'
# copied from: https://github.com/ohmyzsh/ohmyzsh/blob/750d3ac4b493dca13ef0ced55fa6a2cd02dc7ee8/plugins/git/git.plugin.zsh
abbr ga "git add"
abbr gaa "git add --all"
abbr gb "git branch"
abbr gba "git branch --all"
abbr gbd "git branch --delete"
abbr gbm "git branch --move"
abbr gbnm "git branch --no-merged"
abbr gbr 'git branch --remote'
# abbr gc "NVIM_FLATTEN_NEST=1 git commit --verbose"
abbr gc "git commit --verbose"
# abbr gc! 'NVIM_FLATTEN_NEST=1 git commit --verbose --amend'
abbr gc! 'git commit --verbose --amend'
abbr gcb "git checkout -b"
abbr gcf "git config --list | vimpager"
abbr gcl "git clone --recurse-submodules"
abbr gcl1 "git clone --depth 1"
abbr gcm 'git checkout (git_main_branch)'
abbr gco "git checkout"
abbr gcp "git cherry-pick"
abbr gcpa "git cherry-pick --abort"
abbr gcpc "git cherry-pick --continue"
abbr gd "git diff"
abbr gds "git diff --staged"
abbr gdup 'git diff @{upstream}'
abbr gf "git fetch"
abbr ghh "git help"
abbr glg "git log --stat"
abbr glgp "git log --stat --patch"
abbr gm 'git merge'
abbr gma 'git merge --abort'
abbr gmc 'git merge --continue'
abbr gmom 'git merge origin/(git_main_branch)'
abbr gms 'git merge --squash'
abbr gmtl "git mergetool --no-prompt"
abbr gmum 'git merge upstream/(git_main_branch)'
abbr gprav "git pull --rebase --autostash -v"
abbr grb 'git rebase'
abbr grba 'git rebase --abort'
abbr grbc 'git rebase --continue'
abbr grbm 'git rebase (git_main_branch)'
abbr grbo 'git rebase --onto'
abbr grbom 'git rebase origin/(git_main_branch)'
abbr grbs 'git rebase --skip'
abbr grbum 'git rebase upstream/(git_main_branch)'
abbr grv "git remote --verbose"
abbr gsb "git status --short --branch"
abbr gss "git status --short"
abbr gwt 'git worktree'
abbr gwta 'git worktree add'
abbr gwtls 'git worktree list'
abbr gwtmv 'git worktree move'
abbr gwtrm 'git worktree remove'

# SVN
abbr sva 'svn add'
# abbr svc 'NVIM_FLATTEN_NEST=1 svn commit'
abbr svc 'svn commit'
abbr svs 'svn status'
abbr svu 'svn update'
abbr svl --set-cursor 'svn log -v % 2>&1 | vimpager'
abbr svll --set-cursor 'svn log -l % 2>&1 | vimpager'

# Chezmoi
abbr cz chezmoi
abbr czz 'cd (chezmoi source-path)' # chezmoi cd
abbr czs 'chezmoi status'
abbr cza 'chezmoi add'
abbr czat 'chezmoi add --template'
abbr czct 'chezmoi chattr +template'
abbr czet --set-cursor "chezmoi execute-template '%'"
abbr czd 'chezmoi diff'
abbr czap 'chezmoi apply'
abbr czapv 'chezmoi apply -v'
abbr cze 'chezmoi edit'
abbr czeap 'chezmoi edit --apply'
abbr czeapv 'chezmoi edit --apply --verbose'
abbr czu 'chezmoi update'
abbr czm 'chezmoi managed --path-style=absolute .'
abbr czum 'chezmoi unmanaged --path-style=absolute .'
abbr czg 'chezmoi git --'

# Docker
abbr d docker
abbr dcls "docker container ls"
abbr dclsa "docker container ls -a"
abbr dlg "docker container logs"
abbr dpo "docker container port"
abbr dr "docker container run"
abbr drm "docker container rm"
abbr dst "docker container start"
abbr drs "docker container restart"
abbr dstp "docker container stop"
abbr dils "docker image ls"
abbr dirm "docker image rm"
abbr dps "docker ps"
abbr dpsa "docker ps -a"
# Docker Compose
abbr dc "docker compose"
abbr dcps "docker compose ps"
abbr dcup "docker compose up"
abbr dcupd "docker compose up -d"
abbr dcdn "docker compose down"
abbr dclg "docker compose logs"
abbr dclgf "docker compose logs -f"

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

if type -q claude
    abbr cl claude
    abbr clc "claude --continue"
    abbr clr "claude --resume"
end
# https://github.com/musistudio/claude-code-router
if type -q ccr
    abbr ccr "ccr code"
end
if type -q aider
    abbr ad aider
    abbr adr 'aider --model r1'
    abbr adg 'aider --model gemini'
    abbr adc 'aider --model claude'
    abbr adp aider_copilot
end

if type -q atuin
    set -gx ATUIN_NOBIND true
    atuin init fish | source
end

# set -x LESSOPEN "|/opt/homebrew/bin/lesspipe.sh %s"
if type -q batpipe
    eval (batpipe)
end

# if type -q pyenv
#     set -Ux PYENV_ROOT $HOME/.pyenv
#     fish_add_path $PYENV_ROOT/bin
#     pyenv init - | source
#     set -gx PYENV_VIRTUALENV_DISABLE_PROMPT 1
#     pyenv virtualenv-init - | source
# end

if set -q TERMUX_VERSION
    # # https://github.com/nvim-lua/plenary.nvim/issues/536#issuecomment-1799807408
    # set -q XDG_RUNTIME_DIR; or set -gx XDG_RUNTIME_DIR "$PREFIX/tmp"

    abbr pkgu 'pkg update && pkg upgrade'
    abbr pkgi 'pkg install'
    abbr pkgs 'pkg search'
    abbr pkgl 'pkg list-installed'
    abbr open termux-open
    set ll_cmd 'eza --all --color=always --color-scale all --icons=always --long --time-style=iso --git --no-user'
    alias l "$ll_cmd --group-directories-first"
    alias lm "$ll_cmd --sort=modified --classify"
    abbr -a --position anywhere --set-cursor ghh 'git help % | eval $MANPAGER'
    abbr dl 'cd ~/storage/downloads'
    abbr rime 'cd ~/storage/shared/Android/rime'

    if not set -q TMUX
        tmux attach || tmux
    end
else
    # ~/.local/share/bob/nightly/share/nvim/runtime/scripts/less.vim
    alias vless "nvim -u $(brew --prefix)/share/nvim/runtime/scripts/less.vim"

    # # using TUN for now
    # if status is-interactive; or set -q NEOVIDE_FRAME
    #     term_proxy_on
    # end
end
