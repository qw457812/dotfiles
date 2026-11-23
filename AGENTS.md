## Chezmoi

- Edit chezmoi source paths like `dot_*`, `private_*`, and `symlink_*`, not generated target paths.
- Repository-only projects such as `packages/` and `dsh-plugins/` are Git-tracked but excluded from chezmoi's target state by `.chezmoiignore`.
- `write`/`edit` calls on managed source files trigger `chezmoi apply` for the target via the Pi extension `private_dot_pi/private_agent/extensions/chezmoi.ts` or dsh plugin `dsh-plugins/dsh-plugin-chezmoi.mjs`; managed target edits trigger `chezmoi re-add` as a fallback. `bash` edits need a manual `chezmoi apply` scoped to the relevant target path.
- `symlinks/` contains source-state files referenced by `symlink_*` templates.
- Deployment exclusions are listed in `.chezmoiignore`.

## Pi

- Pi config lives under `private_dot_pi/private_agent` and `symlinks/pi/agent`.
- Pi global settings file lives at `symlinks/pi/agent/settings.json`.
- When working on `private_dot_pi/private_agent/extensions`, the Pi source checkout is available for reference at `~/.local/share/nvim/lazy/pi`.
- After TypeScript changes under `private_dot_pi/private_agent`, run `npm --prefix private_dot_pi/private_agent run check` and `npm --prefix private_dot_pi/private_agent run lint` from the chezmoi repository root.

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

## Herdr

- Herdr app config lives under `dot_config/herdr-app`; read `~/.config/herdr-app/AGENTS.md` before changing layouts, keys, or mods.
- herdr-core config lives under `dot_config/herdr-core`.

## Rime

- `private_Library/Rime/` holds the shared Rime files and deploys to `~/Library/Rime` on macOS; Fedora (`dot_local/share/fcitx5/rime/`) and Android (`dot_config/trime/`) mirror the shared files through one-line `include` templates.
- Frontend-specific files live in their platform dir: `squirrel.custom.yaml` (macOS), `fcitx5.yaml` (Linux), `custom.trime.yaml` (Android).
- For upstream TigerCode data syncs, read `.agents/skills/sync-tiger/SKILL.md`.

## Interactive Testing with tmux

For interactive TUI tests, follow `.agents/skills/interactive-testing/SKILL.md`.

## Commit Guidelines

- Use subsystem/component scopes matching repository history, e.g. `pi/prompt-editor`, `nvim/sidekick`.
