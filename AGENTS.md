## Chezmoi

- Edit chezmoi source paths like `dot_*`, `private_*`, and `symlink_*`, not generated target paths.
- Do not run `chezmoi apply` manually; agent hooks such as `private_dot_pi/private_agent/extensions/chezmoi.ts` run it when needed.
- `symlinks/` contains source-state files referenced by `symlink_*` templates.
- Deployment exclusions are listed in `.chezmoiignore`.

## Pi

- Pi config lives under `private_dot_pi/private_agent` and `symlinks/pi/agent`.
- When working on `private_dot_pi/private_agent/extensions`, the Pi source checkout is available for reference at `~/.local/share/nvim/lazy/pi`.
- After TypeScript changes under `private_dot_pi/private_agent/extensions`, run `npm run check` and `npm run lint` in `private_dot_pi/private_agent`.

## Neovim

- Neovim config lives under `dot_config/nvim`, based on LazyVim.
- Prefer existing helpers in `dot_config/nvim/lua/util` and current plugin-spec patterns.
- Lua style: Stylua, 2-space indent, 120-column width.
- Host-specific lock/config files live under `symlinks/nvim/{macos,termux,fedora-asahi}`.
