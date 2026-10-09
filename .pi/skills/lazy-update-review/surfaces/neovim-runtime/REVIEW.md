# Neovim runtime versus lazy checkout

For `github.com/neovim/neovim`, distinguish the lazy-managed source checkout from
the executable and its bundled runtime.

1. Find the owning spec and its build hook, then identify the executable:

   ```bash
   rg -n 'neovim/neovim|bob|nvimExecutablePaths' dot_config/nvim dot_config/private_fish symlinks/vscode symlinks/homebrew
   command -v nvim
   nvim --version
   ```

   A spec without a build hook only updates the source checkout. Bob may already
   have installed the target binary independently. Record both versions; preserve
   existing spec edits.

   **Complete when:** source installed/target, executable version, and the actual
   install/build owner are distinguished.

2. Review the reported source range against local runtime references, including
   internal APIs, removed options, default mappings, and copied upstream helpers:

   ```bash
   rg -n 'isprint|isident|mcursor|DiffUpdated|get_captures_at_pos|_tagfunc|_watch|TabLine|vim\.lsp\.completion' dot_config/nvim
   ```

   Extend the search with names changed in the range. Check copied helpers against
   the upstream diff even when their original source URL is only a comment. If the
   executable matches the target, use it for focused compatibility tests; otherwise
   report that target behavior remains untested. Use `+qa!` when tests modify buffers.

   **Complete when:** every matching local reference is accounted for, and the report
   distinguishes static review from tests on the target runtime.
