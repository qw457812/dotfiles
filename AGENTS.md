## Chezmoi

- For a managed target, edit the source returned by `chezmoi source-path <target>`. Get the user's confirmation before tracking an unmanaged target.
- For linked config, edit the backing file (e.g. `symlinks/pi/agent/settings.json` or `symlinks/dsh/settings.yaml`) to change content; edit `symlink_*` to change the destination. To convert a managed plain file to a symlink, follow the [conversion procedure](.agents/skills/chezmoi-symlink/SKILL.md).
- Pi and dsh `write`/`edit` hooks run `chezmoi apply` for managed source edits and `chezmoi re-add` for managed target edits. After `bash` edits to managed sources, run `chezmoi apply <target>` for each affected target.
- Check `.chezmoiignore` for repo-only paths. For shared config, check its exclusions and the template branches for macOS, Android (Termux), and Fedora Asahi Remix.

## Change conventions

- Read each file in full before editing it. For broad changes, investigations, and audits, read all relevant files in full.
- Inline one-line helpers with a single call site. Preserve backward compatibility only when requested.
- For interactive TUI tests, follow the [tmux test procedure](.agents/skills/interactive-testing/SKILL.md).
- For commits, match the subsystem/component scope in the affected paths' history (e.g. `pi/prompt-editor`).

## Subsystem guidance

- **Pi extensions:** Consult `~/.local/share/nvim/lazy/pi` for extension APIs. After any TypeScript change under `private_dot_pi/private_agent/`, run `npm run check && npm run lint` in that directory; both must pass.
- **Pi updates:** The lazy.nvim build hooks for Pi itself and its packages are in `dot_config/nvim/lua/plugins/ai.lua`.
- **DeepSeek Harness plugins:** When changing source-loaded modules in `dsh-plugins/` or building, installing, or publishing profile-scoped npm bundles from `packages/`, follow the [dsh plugin workflow](.dsh/skills/dsh-plugin/SKILL.md) for wiring and validation.
- **Neovim:** Check inherited defaults in `~/.local/share/nvim/lazy/LazyVim` and plugin behavior in sibling checkouts. Match neighboring specs, reuse helpers in `dot_config/nvim/lua/util/`, and format Lua with StyLua. Keep host-specific locks and config in `symlinks/nvim/<host>/`.
- **Herdr:** Read `~/.config/herdr-app/AGENTS.md` before changing `dot_config/herdr-app/` or `dot_config/herdr-core/`.
- **Rime:** Edit shared files in `private_Library/Rime/`; `dot_local/share/fcitx5/rime/` and `dot_config/trime/` include them. Keep frontend overrides in their platform directory. For upstream TigerCode reviews or syncs, follow the [sync procedure](.agents/skills/sync-tiger/SKILL.md).
