-- https://github.com/appelgriebsch/Nv/blob/e9a584090a69a8d691f5eb051e76016b65dfc0b7/lua/plugins/extras/ui/onedarkpro-theme.lua
-- https://github.com/appelgriebsch/Nv/blob/e9a584090a69a8d691f5eb051e76016b65dfc0b7/lazyvim.json#L25
return {
  -- disable tokyonight
  { "folke/tokyonight.nvim", enabled = false },

  -- add onedarkpro
  {
    "olimorris/onedarkpro.nvim",
    priority = 1000,
  },

  -- configure LazyVim to load onedarkpro theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
