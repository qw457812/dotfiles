-- LazyVim Extras: lang.python
-- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/python.lua
return {
  -- makes pyright and debugpy aware of the selected virtual environment
  -- https://github.com/chrisgrieser/nvim-kickstart-python/blob/ad0ef92a37618f76cf815800800c1f13c04dcf68/kickstart-python.lua#L424
  -- https://github.com/Relrin/dotfiles/blob/7c8526d7f8ade76310bdd949d31929edddd086c8/nvim/lua/plugins/extras/lang/python.lua#L82
  {
    "linux-cultist/venv-selector.nvim",
    opts = function(_, opts)
      if LazyVim.has("nvim-dap-python") then
        opts.dap_enabled = true -- makes the debugger work with venv
      end
      return vim.tbl_deep_extend("force", opts, {
        -- TODO can't detect miniconda3 env
        -- anaconda_base_path = "~/miniconda3",
        -- anaconda_envs_path = "~/miniconda3/envs",
        name = {
          "venv",
          ".venv",
          "env",
          ".env",
        },
      })
    end,
  },
}
