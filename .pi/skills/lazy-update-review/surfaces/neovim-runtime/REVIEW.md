# Neovim: source checkout or running binary?

1. **Identify the installer.** Compare the reported source range with `command -v nvim` and `nvim --version`. Trace the lazy build hook and executable selectors (search for `neovim/neovim`, `bob` and `nvimExecutablePaths` in Neovim, Fish, Homebrew and VS Code config). A spec without a build hook updates only source; Bob can already have installed the target independently. Preserve existing spec edits.

   **Done when:** the report names the checkout range, running executable/build and owner of binary/runtime updates.

2. **Trace the runtime diff.** Search `dot_config/nvim` for identifiers changed in that range, including private APIs, removed options, default mappings and copies of upstream helpers. Compare copied code even when the only upstream reference is a URL in a comment. If the executable matches the target, run focused compatibility tests with it (use `+qa!` for modified buffers).

   **Done when:** each matching reference has a finding, and tests on the target binary are distinguished from static review or an untested target.
