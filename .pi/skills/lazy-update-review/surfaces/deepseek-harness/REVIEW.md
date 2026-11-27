# DeepSeek Harness: which release will the hook install?

1. **Resolve the CLI channel.** Read the lazy build command and its helpers in `dot_config/nvim/lua/{plugins,util}`. Compare the source target's CLI version, `dsh --version` and `npm view @deepseek-ai/dsh dist-tags --json`. A checkout on a prerelease tag can still install `latest` rather than `next`.

   **Done when:** the installed CLI, target checkout and version the hook would install are recorded, including any mismatch.

2. **Trace profile composition.** Follow the changed settings, commands, tools, services and APIs from upstream docs/schema diffs to the deployed profiles (`dot_dsh/`, `symlinks/dsh/`), source-loaded plugins (`dsh-plugins/`) and independently published bundles (`packages/`). For each consumer check the owning manifest and API pins, workspace, lockfile, Cordis patch and update helper. Valid YAML can still acquire a different default or CLI behavior.

   **Done when:** every affected profile, plugin and bundle is classified against the runtime the hook selects; name required edits or user choices separately from compatible settings.
