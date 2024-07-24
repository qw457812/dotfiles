-- https://github.com/appelgriebsch/Nv/blob/e9a584090a69a8d691f5eb051e76016b65dfc0b7/lua/plugins/extras/ui/onedarkpro-theme.lua
return {
  { "folke/tokyonight.nvim", cond = false },
  { "catppuccin/nvim", cond = false },

  {
    "olimorris/onedarkpro.nvim",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
