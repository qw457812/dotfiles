-- LazyVim Extras: lang.python
-- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/python.lua
return {
  -- note that LazyVim use the new "regexp" branch: https://github.com/linux-cultist/venv-selector.nvim/tree/regexp
  {
    "linux-cultist/venv-selector.nvim",
    -- TODO temp fix: venv-selector does not work with extras.editor.fzf
    -- https://github.com/LazyVim/LazyVim/issues/3612
    -- https://github.com/linux-cultist/venv-selector.nvim/issues/142
    dependencies = {
      { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
    },
    -- https://github.com/linux-cultist/venv-selector.nvim/tree/regexp?tab=readme-ov-file#your-own-anaconda-search
    -- https://github.com/Spreadprism/nvim/blob/c0f60a5dac485651e7a8005155c42ea6fb8b3069/lua/plugins/lsp.lua#L27
    -- https://github.com/popshia/nvim/blob/0b1567719e2b2cfed0e96d67c804e1379ced9a76/lua/user/plugins/venv-selector.lua#L22
    opts = {
      settings = {
        options = {
          -- -- missing duplicate name of different path
          -- on_telescope_result_callback = function(filename)
          --   filename = filename:gsub("/bin/python", "") ---@type string
          --   filename = vim.split(filename, "/")
          --   filename = filename[#filename]
          --   if filename == "miniconda3" then
          --     filename = "base"
          --   end
          --   return filename
          -- end,
          -- for linux/mac: replace the home directory with '~' and remove the /bin/python part.
          on_telescope_result_callback = function(filename)
            return filename:gsub(os.getenv("HOME"), "~"):gsub("/bin/python", "")
          end,
        },
        search = {
          anaconda_base = {
            -- command = "fd /bin/python$ ~/miniconda3 --full-path --color never -E /proc -E /pkgs", -- include `base` of calling `conda env list`
            command = "fd /bin/python$ ~/miniconda3/envs --full-path --color never -E /proc",
            type = "anaconda",
          },
        },
      },
    },
  },
}
