-- https://github.com/AstroNvim/astrocommunity/blob/b25c9e729369f9f52f2986bb8543f45549fed206/lua/astrocommunity/pack/xml/init.lua
-- https://github.com/Matt-FTW/dotfiles/blob/797f09fdd831514c994fce88e8ded23fbd08edc0/.config/nvim/lua/plugins/extras/lang/xml.lua
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "xml",
        callback = function()
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
        end,
      })
    end,
  },

  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   opts = { ensure_installed = { "xml", "html" } },
  -- },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lemminx = {},
      },
    },
  },

  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "lemminx" } },
  },
}
