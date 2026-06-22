## Repository

- This is a chezmoi source repo. Edit source paths like `dot_*`, `private_*`, and `symlink_*`,
  not generated target paths.
- Shared symlink targets live under `symlinks/`.
- Deployment exclusions are listed in `.chezmoiignore`.
- Do not run `chezmoi apply` manually; agent hooks such as
  `private_dot_pi/private_agent/extensions/chezmoi.ts` run it when needed.

## Pi Agent

- Pi agent source: `private_dot_pi/private_agent`.
- Shared Pi agent config/data lives under `symlinks/pi/agent`.
- For TypeScript extension changes, run `npm run check` and `npm run lint` there.

## Neovim

- Neovim source: `dot_config/nvim`, based on LazyVim.
- Prefer existing `lua/util` helpers and current plugin-spec patterns.
- Lua style: Stylua, 2-space indent, 120-column width.
- Host lock/config files live under `symlinks/nvim/{macos,termux,fedora-asahi}`.
