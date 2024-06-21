-- https://www.lazyvim.org/plugins/colorscheme#catppuccin
return {
  -- disable tokyonight
  -- { "folke/tokyonight.nvim", enabled = false },

  -- LazyVim already add catppuccin in ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/colorscheme.lua

  -- configure LazyVim to load catppuccin theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
