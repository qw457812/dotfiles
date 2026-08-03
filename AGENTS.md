## Chezmoi

- Edit chezmoi source paths like `dot_*`, `private_*`, and `symlink_*`, not generated target paths.
- Do not run `chezmoi apply` manually; the agent hook `private_dot_pi/private_agent/extensions/chezmoi.ts` runs it when needed.
- `symlinks/` contains source-state files referenced by `symlink_*` templates.
- Deployment exclusions are listed in `.chezmoiignore`.

## Pi

- Pi config lives under `private_dot_pi/private_agent` and `symlinks/pi/agent`.
- Pi global settings file lives at `symlinks/pi/agent/settings.json`.
- When working on `private_dot_pi/private_agent/extensions`, the Pi source checkout is available for reference at `~/.local/share/nvim/lazy/pi`.
- After TypeScript changes under `private_dot_pi/private_agent/extensions`, run `npm run check` and `npm run lint` in `private_dot_pi/private_agent`.

## Neovim

- Neovim config lives under `dot_config/nvim`; it imports LazyVim defaults from `~/.local/share/nvim/lazy/LazyVim`, then local lazy.nvim specs merge with and override those defaults.
- lazy.nvim-managed plugin checkouts live under `~/.local/share/nvim/lazy/<plugin>` and are available for reference when changing plugin specs or config.
- lazy.nvim also manages non-Neovim package checkouts, including Pi itself and Pi packages such as `~/.local/share/nvim/lazy/agent-stuff`; their lazy specs define the `pi update --self` and `pi update --extension <package>` build hooks in `dot_config/nvim/lua/plugins/ai.lua`.
- Prefer existing helpers in `dot_config/nvim/lua/util` and current plugin-spec patterns.
- Lua style: Stylua, 2-space indent, 120-column width.
- Host-specific lock/config files live under `symlinks/nvim/{macos,termux,fedora-asahi}`.

## Fish

- Fish config lives under `dot_config/private_fish` and `symlinks/fish`.

## Interactive TUI Testing

- Test interactive terminal applications in a controlled tmux session; do not
  infer TUI behavior from static checks alone.
- Start each app in a fresh fixed-size session, wait for startup, send literal text
  separately from special keys, capture the pane, and clean up:

  ```bash
  TEMP_DIR="${TMPDIR:-/tmp}"
  SOCKET_DIR="${CLAUDE_TMUX_SOCKET_DIR:-$TEMP_DIR/claude-tmux-sockets}"
  RUN_ID="tui-test-$(date +%s)-$$"
  SOCKET="$SOCKET_DIR/$RUN_ID.sock"
  SESSION="$RUN_ID"
  APP='pi --no-session' # replace with the interactive command under test
  INPUT='/hotkeys'      # replace with non-destructive test input

  mkdir -p "$SOCKET_DIR"
  tmux -S "$SOCKET" -f /dev/null new-session -d -s "$SESSION" -c "$TEMP_DIR" -x 80 -y 24
  tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -l -- "$APP"
  tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 Enter
  sleep 3
  tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION":0.0 -S -200
  tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -l -- "$INPUT"
  tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 Enter
  sleep 1
  tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION":0.0 -S -200
  tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 Escape # special keys (also C-o for ctrl+o, etc.)
  sleep 1
  tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION":0.0 -S -200
  tmux -S "$SOCKET" kill-session -t "$SESSION"
  ```

- Pause after startup and between text input and mode-changing keys such as
  `Escape`; sending them in one burst can be interpreted as a terminal escape
  sequence. Capture and inspect the resulting application and terminal state before
  cleanup.
