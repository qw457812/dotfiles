# DSH profile package review

Use this branch for lazy-managed packages that are installed into a DSH profile by a lazy build hook.

1. Find the lazy owner, profile update helper, and deployed profile sources:

   ```bash
   rg -n "<repo>|<npm-package>|update_plugin" \
     dot_config/nvim/lua/plugins dot_config/nvim/lua/util \
     dot_dsh symlinks/dsh
   find dot_dsh/profiles symlinks/dsh/profiles -path "*<profile>*" -type f -print
   ```

   Confirm whether the build hook updates the profile `package.json`, lockfile, or both. Treat
   symlinked files under `symlinks/dsh/` as the chezmoi source even when the package manager writes
   through their deployed `~/.dsh/` paths.

2. Compare the target package's `package.json` with the installed DSH, Node, and package-manager
   versions. Check the profile's `package.json`, `pnpm-workspace.yaml`, lockfile, and Cordis patch for
   changed peer ranges, native dependencies, release-age exceptions, install scripts, and renamed
   bundle or service IDs:

   ```bash
   dsh --version
   node --version
   pnpm --version
   rg -n "<npm-package>|<changed-dependency-or-service>" \
     dot_dsh/profiles/<profile> symlinks/dsh/profiles/<profile>
   ```

3. Diff upstream configuration docs and schemas, then account for every matching runtime setting and
   legacy environment/data-path reference:

   ```bash
   rg -n "<changed-key>|<legacy-name>|<env-prefix>" \
     dot_dsh symlinks/dsh dot_config private_dot_* packages dsh-plugins
   ```

**Complete when:** the lazy build hook's writes are mapped to their chezmoi sources; the target package
is compatible with the installed DSH/Node toolchain; profile dependency, workspace, lockfile, and
Cordis surfaces are classified; and every local setting or legacy name affected by the exact range is
valid, edited, or reported as a user choice.
