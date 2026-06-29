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
