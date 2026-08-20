# DeepSeek Harness review

Use this branch for `github.com/deepseek-ai/deepseek-harness`.

1. Find the lazy owner and global CLI build hook:

   ```bash
   rg -n "deepseek-harness|@deepseek-ai/dsh" dot_config/nvim/lua/plugins dot_config/nvim/lua/util
   ```

   Compare the target CLI version with the installed CLI and npm dist-tags. A
   prerelease may be published under `next` while an unqualified install still
   resolves `latest`:

   ```bash
   dsh --version
   npm view @deepseek-ai/dsh dist-tags --json
   ```

2. Account for profile composition, settings, direct source-loaded plugins, and
   local publishable bundles:

   ```bash
   rg -n "<changed-package-or-key>|@deepseek-ai/dsh" \
     dot_dsh symlinks/dsh dsh-plugins packages
   find dot_dsh symlinks/dsh -name 'pnpm-lock.yaml*' -print
   ```

   Treat `dot_dsh/` and `symlinks/dsh/` as deployed profile/config sources,
   `dsh-plugins/` as direct runtime plugins, and `packages/` as independently
   published bundles. Check the owning `package.json`, `pnpm-workspace.yaml`,
   lockfile, Cordis patch, and lazy update helper for every matching surface.

3. Diff upstream docs and schemas for each matching setting, command, tool,
   service, or API. In particular, classify changed defaults and CLI behavior
   even when the local YAML remains schema-valid.

**Complete when:** the global CLI build resolves the target release channel; each
profile bundle/build hook and runtime config reference is classified as valid,
requiring an edit, or awaiting a user preference; and local plugin/package API
pins are checked against the target runtime surface.
