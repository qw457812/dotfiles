-- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/colorscheme.lua
return {
  { "folke/tokyonight.nvim", cond = false },
  { "catppuccin/nvim", cond = false },

  {
    "craftzdog/solarized-osaka.nvim",
    lazy = true,
    priority = 1000,
    opts = function()
      return {
        transparent = true,
      }
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "solarized-osaka",
    },
  },
}
