return {
  -- disable built-in themes
  -- { "folke/tokyonight.nvim", enabled = false },
  -- { "catppuccin/nvim", enabled = false },

  -- add sonokai
  {
    "sainnhe/sonokai",
    priority = 1000,
  },

  -- configure LazyVim to load sonokai theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "sonokai",
    },
  },
}
