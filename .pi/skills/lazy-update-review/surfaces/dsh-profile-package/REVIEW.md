# DSH packages installed by a profile build hook

1. **Map the writes.** Follow the lazy spec into its profile update helper in `dot_config/nvim/lua/util`. Trace the affected profile's manifest and lockfile from the deployed `~/.dsh/` paths back to `dot_dsh/` or `symlinks/dsh/`: the package manager can write through the symlink.

   **Done when:** the hook's profile, npm package and every file it updates have named chezmoi source paths.

2. **Check the install contract.** Compare the target package manifest with `dsh --version`, `node --version` and `pnpm --version`. Read the profile's `package.json`, `pnpm-workspace.yaml`, lockfile and Cordis patch for changed peer ranges, native dependencies, release-age exceptions, install scripts and bundle/service IDs.

   **Done when:** each affected install constraint or service is accounted for, including any incompatibility that would block the build.

3. **Check runtime settings.** Diff the upstream docs and schema across the exact range. Search for both new and legacy keys, environment variables and data paths across profiles, `dot_config/`, `private_dot_*`, `packages/` and `dsh-plugins/`.

   **Done when:** each affected setting is still valid, needs a named source edit, or awaits a user choice.
