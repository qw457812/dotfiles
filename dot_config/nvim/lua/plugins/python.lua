-- require lazyvim.plugins.extras.lang.python
if not LazyVim.has_extra("lang.python") then
  return {}
end

return {
  -- note that LazyVim use the new "regexp" branch: https://github.com/linux-cultist/venv-selector.nvim/tree/regexp
  {
    "linux-cultist/venv-selector.nvim",
    optional = true,
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
          -- for linux/mac: replace the home directory with `~` and remove the /bin/python part.
          on_telescope_result_callback = function(filename)
            return require("util.path").replace_home_with_tilde(filename):gsub("/bin/python", "")
          end,
        },
        search = {
          -- see: ~/.local/share/nvim/lazy/venv-selector.nvim/lua/venv-selector/config.lua
          anaconda_envs = {
            command = "$FD 'bin/python$' ~/miniconda3/envs --full-path --color never -E /proc",
            type = "anaconda",
          },
          anaconda_base = {
            command = "$FD '/python$' ~/miniconda3/bin --full-path --color never -E /proc",
            type = "anaconda",
          },
        },
      },
    },
  },

  -- isort
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "isort")
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.isort)
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      -- require lazyvim.plugins.extras.formatting.black
      if LazyVim.has_extra("formatting.black") then
        opts.formatters_by_ft = opts.formatters_by_ft or {}
        -- run multiple formatters sequentially
        opts.formatters_by_ft.python = { "isort", "black" }
      end
    end,
  },

  -- -- TODO should I add this?
  -- -- correctly setup mason dap extensions
  -- -- https://github.com/dylanHanger/dotfiles/blob/2289dc2443c1d513117a94d16b0fa7f962e03c6a/.config/nvim/lua/plugins/lang/python.lua#L22
  -- {
  --   "jay-babu/mason-nvim-dap.nvim",
  --   opts = function(_, opts)
  --     vim.list_extend(opts.ensure_installed, { "debugpy" })
  --   end,
  -- },
}
