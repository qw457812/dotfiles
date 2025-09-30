# Path
fish_add_path ~/go/bin
set -q TERMUX_VERSION; or fish_add_path ~/.cargo/bin # https://github.com/rust-lang/rustup/blob/5e59246c45756b860ffa2c0e471e9989f0d56ff8/doc/user-guide/src/installation/already-installed-rust.md?plain=1#L63-L66
fish_add_path ~/.local/share/bob/nvim-bin
fish_add_path ~/.local/bin
fish_add_path "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
fish_add_path "$HOME/Library/Application Support/Coursier/bin" # scalafmt

# Exports
# set -gx TERM xterm-256color # https://github.com/gpakosz/.tmux
set -q NEOVIDE_FRAME; and set -gx TERM xterm-256color
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx LC_CTYPE en_US.UTF-8
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx EDITOR (which nvim)
set -gx VISUAL $EDITOR
set -gx SUDO_EDITOR $EDITOR

if status is-interactive # https://github.com/ndonfris/fish-lsp/blob/1be77fcfa37d9d3877994f14163c7faacf7a533e/fish_files/get-documentation.fish
    # set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -x MANPAGER 'nvim --cmd "lua vim.g.manpager = true" -c "nnoremap d <C-d>|lua vim.defer_fn(function() vim.api.nvim_command(\"silent! nunmap dd|nnoremap u <C-u>\") end, 500)" +Man!'
end
# set -x MANROFFOPT -c
set -x EZA_MIN_LUMINANCE 50
set -x DYLD_LIBRARY_PATH /opt/homebrew/opt/librime/lib # https://github.com/wlh320/rime-ls#macos
set -x RIPGREP_CONFIG_PATH $HOME/.ripgreprc
set -x LG_CONFIG_FILE $HOME/.config/lazygit/config.yml,$HOME/.cache/nvim/lazygit-theme.yml

# ==============================================================================
# EXIT IF NOT INTERACTIVE
# ==============================================================================
status is-interactive; or exit

# Cursor styles
set -gx fish_vi_force_cursor 1
set -gx fish_cursor_default block
set -gx fish_cursor_insert line blink
set -gx fish_cursor_visual block
set -gx fish_cursor_replace_one underscore

# Fish
set -g fish_greeting
set fish_emoji_width 2
alias ssh "TERM=xterm-256color command ssh"
alias mosh "TERM=xterm-256color command mosh"

set -g __proxy_ip "127.0.0.1"
set -g __http_proxy_port 10808
set -g __socks_proxy_port $__http_proxy_port

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
abbr zr "cd (git rev-parse --show-toplevel)"
abbr cdt "cd (mktemp -d)"
abbr ncdu "ncdu --color dark"
abbr pwdc "pwd | tr -d '\n' | fish_clipboard_copy"
abbr paths 'echo $PATH | tr " " "\n" | nl'
abbr dl "cd ~/Downloads"

# Editor & Pager
abbr vim nvim
abbr vi nvim
abbr v nvim
abbr v! "nvim -u NONE"
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
abbr gdw "git diff --word-diff"
abbr gdsw "git diff --staged --word-diff"
abbr gdi "git diff --ignore-all-space --ignore-blank-lines --ignore-cr-at-eol"
abbr gdsi "git diff --staged --ignore-all-space --ignore-blank-lines --ignore-cr-at-eol"
abbr glgpi "git log --stat --patch --ignore-all-space --ignore-blank-lines --ignore-cr-at-eol"
abbr gwtab 'git worktree add -b'
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
abbr dls "docker container ls"
abbr dlsa "docker container ls -a"
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
abbr dvi "docker volume inspect"
abbr dvls "docker volume ls"
abbr dvprune "docker volume prune"
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
abbr bbd 'brew bundle dump --global --force'

# AI
if type -q claude
    # claude mcp add -s user context7 -- npx -y @upstash/context7-mcp --api-key $CONTEXT7_API_KEY
    # claude mcp add -s user playwright npx @playwright/mcp@latest
    # claude mcp add -s user magic -- npx -y @21st-dev/magic@latest
    # claude mcp add -s user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
    # claude mcp add -s user -t http deepwiki https://mcp.deepwiki.com/mcp
    # claude mcp add -s user --transport http grep https://mcp.grep.app
    # claude mcp add -s user exa -e EXA_API_KEY=$EXA_API_KEY -- npx -y exa-mcp-server --tools=get_code_context_exa
    # claude mcp add -s user exa -e EXA_API_KEY=$EXA_API_KEY -- npx -y exa-mcp-server --tools=deep_researcher_start,deep_researcher_check
    # claude mcp add -s user -t http exa https://mcp.exa.ai/mcp
    # claude mcp add -s user firecrawl -e FIRECRAWL_API_KEY=$FIRECRAWL_API_KEY -- npx -y firecrawl-mcp
    # claude mcp add -s user codex -- codex mcp serve
    abbr cl claude
    abbr clt claude_temp
    abbr clc "claude --continue"
    abbr clr "claude --resume"
    abbr clv "claude --verbose"
    abbr cld "claude --debug"
    abbr cls "claude --model sonnet"
    abbr clo "claude --model opus"
    abbr clp "claude --model opusplan --permission-mode plan"
    abbr clk "MAX_THINKING_TOKENS=31999 claude"
    abbr clko "MAX_THINKING_TOKENS=31999 claude --model opus"
    abbr clkt "MAX_THINKING_TOKENS=31999 claude_temp"
    abbr clgc "claude --model sonnet 'commit only the staged changes'"
    set -l ccusage (type -q bunx; and echo "bunx ccusage"; or echo "npx ccusage@latest")
    abbr ccu "$ccusage"
    abbr ccum "$ccusage daily --breakdown"
    abbr ccub "$ccusage blocks"
    if type -q claude-monitor # https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor
        abbr ccm "claude-monitor --view realtime"
        abbr ccmd "claude-monitor --view daily"
        abbr ccmm "claude-monitor --view monthly"
    end
    abbr ccstl (type -q bunx; and echo "bunx ccstatusline@latest"; or echo "npx ccstatusline@latest")
    abbr spec "uvx --from git+https://github.com/github/spec-kit.git specify init --script sh --ai claude --here"
    abbr cchistory "npx cchistory"
    abbr ccexp (type -q bunx; and echo "bunx ccexp@latest"; or echo "npx ccexp@latest")
    abbr cctmpl "ANTHROPIC_BASE_URL=$CTOK_BASE_URL ANTHROPIC_AUTH_TOKEN=$CTOK_AUTH_TOKEN npx claude-code-templates@latest"
    abbr cck claude_kimi
    abbr ccg claude_glm
    abbr ccq claude_qwen
    type -q ccr; and abbr ccr "ccr code" # https://github.com/musistudio/claude-code-router
end
type -q codex; and abbr cx codex # codex completion fish >~/.config/fish/completions/codex.fish
# type -q gemini; and abbr gm gemini
if type -q opencode
    abbr oc opencode
    abbr occ 'opencode --continue'
    abbr ocg 'opencode --model opencode/grok-code'
end
if type -q aider
    abbr ad aider
    abbr adr 'aider --model r1'
    abbr adg 'aider --model gemini'
    abbr adc 'aider --model claude'
    abbr adp aider_copilot
end

# Other
abbr b "cd -"
abbr q exit
abbr reload "exec fish -l"
abbr fda "fd -IH"
abbr rga "rg -uu"
abbr lzd lazydocker
abbr zj zellij
abbr py python3
abbr mk make

if set -q TERMUX_VERSION
    alias pkgbackup 'pkg list-installed >(chezmoi source-path)/backup/termux-packages 2>/dev/null'
    abbr pkgu 'pkg update && pkg upgrade && pkgbackup'
    abbr pkgi --set-cursor 'pkg install % && pkgbackup'
    abbr pkgs 'pkg search'
    abbr pkgl 'pkg list-installed'
    abbr open termux-open
    set ll_cmd 'eza --all --color=always --color-scale all --icons=always --long --time-style=iso --git --no-user'
    alias l "$ll_cmd --group-directories-first"
    alias lm "$ll_cmd --sort=modified --classify"
    abbr -a --position anywhere --set-cursor ghh 'git help % | eval $MANPAGER'
    abbr dl 'cd ~/storage/downloads'
    abbr rime 'cd ~/storage/shared/Android/rime'

    # Auto start tmux on Termux
    set -q TMUX; or tmux attach || tmux
end
