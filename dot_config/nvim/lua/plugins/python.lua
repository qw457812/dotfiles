-- LazyVim Extras: lang.python
-- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/python.lua
return {
  -- {
  --   "mfussenegger/nvim-dap-python",
  --   config = function()
  --     -- https://github.com/mfussenegger/nvim-dap-python#usage
  --     -- I have to run `:lua require("dap-python").setup("/path/to/venv/bin/python")` manually at first time
  --     -- `:lua print(require("dap-python").resolve_python())`
  --     -- and `/path/to/venv/bin/python -m debugpy --version` must work in the shell
  --     -- https://github.com/cstsunfu/.sea.nvim/blob/1bc1ae5cd6445ab05848a2fe3e46408e739986b0/lua/configure/dap_python.lua#L13
  --     require("dap-python").setup(LazyVim.get_pkg_path("debugpy", "/venv/bin/python"))
  --   end,
  -- },

  -- makes pyright and debugpy aware of the selected virtual environment
  -- https://github.com/chrisgrieser/nvim-kickstart-python/blob/ad0ef92a37618f76cf815800800c1f13c04dcf68/kickstart-python.lua#L424
  -- https://github.com/Relrin/dotfiles/blob/7c8526d7f8ade76310bdd949d31929edddd086c8/nvim/lua/plugins/extras/lang/python.lua#L82
  {
    "linux-cultist/venv-selector.nvim",
    dependencies = { "mfussenegger/nvim-dap-python", "mfussenegger/nvim-dap" },
    opts = {
      dap_enabled = true, -- makes the debugger work with venv
    },
  },
}
