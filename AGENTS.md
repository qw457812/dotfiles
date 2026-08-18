## Chezmoi

- Edit chezmoi source paths like `dot_*`, `private_*`, and `symlink_*`, not generated target paths.
- Repository-only projects such as `packages/` and `dsh-plugins/` are Git-tracked but excluded from chezmoi's target state by `.chezmoiignore`.
- Successful `write`/`edit` tool calls in the chezmoi source normally trigger `chezmoi apply` automatically via the active Pi extension `private_dot_pi/private_agent/extensions/chezmoi.ts` or dsh plugin `dsh-plugins/dsh-plugin-chezmoi.mjs`. Run manual `chezmoi apply` when needed and scope it to the relevant target paths.
- `symlinks/` contains source-state files referenced by `symlink_*` templates.
- Deployment exclusions are listed in `.chezmoiignore`.

## Pi

- Pi config lives under `private_dot_pi/private_agent` and `symlinks/pi/agent`.
- Pi global settings file lives at `symlinks/pi/agent/settings.json`.
- When working on `private_dot_pi/private_agent/extensions`, the Pi source checkout is available for reference at `~/.local/share/nvim/lazy/pi`.
- After TypeScript changes under `private_dot_pi/private_agent/extensions`, run `npm --prefix private_dot_pi/private_agent run check` and `npm --prefix private_dot_pi/private_agent run lint` from the chezmoi repository root.

## DeepSeek Harness

- Dsh home config lives under `dot_dsh/`; source-loaded direct plugins live under `dsh-plugins/`; publishable npm bundle sources live under `packages/` and are installed per profile through its `package.json`.
- The `~/.dsh` home patch (`dot_dsh/cordis.patch.yml.tmpl`) explicitly loads direct plugins from the chezmoi source directory.
- Dsh global settings file lives at `symlinks/dsh/settings.yaml`.
- For both direct plugins under `dsh-plugins/` and profile-scoped npm bundles under `packages/`, the dsh source checkout is available for reference at `~/.local/share/nvim/lazy/deepseek-harness`.
- After changes under `dsh-plugins`, run `pnpm --dir dsh-plugins run check` and `pnpm --dir dsh-plugins run lint` from the chezmoi repository root.
- Before publishing a bundle under `packages/`, run its `check` script and inspect `npm pack --dry-run` output.

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

Test interactive terminal applications in a fresh, fixed-size tmux session with
a unique socket. Wait after startup and interactions, send literal text separately
from special keys, inspect captured output, and clean up:

```bash
TEMP_DIR="${TMPDIR:-/tmp}"
SOCKET_DIR="${CLAUDE_TMUX_SOCKET_DIR:-$TEMP_DIR/claude-tmux-sockets}"
SESSION="tui-test-$(date +%s)-$$"
SOCKET="$SOCKET_DIR/$SESSION.sock"
TARGET="$SESSION:0.0"

mkdir -p "$SOCKET_DIR"
tmux -S "$SOCKET" -f /dev/null new-session -d -s "$SESSION" -c "$TEMP_DIR" -x 80 -y 24 'pi --no-session'
sleep 3
tmux -S "$SOCKET" capture-pane -p -J -t "$TARGET" -S -200
tmux -S "$SOCKET" send-keys -t "$TARGET" -l -- '/hotkeys'
tmux -S "$SOCKET" send-keys -t "$TARGET" Enter
sleep 1
tmux -S "$SOCKET" capture-pane -p -J -t "$TARGET" -S -200
tmux -S "$SOCKET" kill-session -t "$SESSION"
```
