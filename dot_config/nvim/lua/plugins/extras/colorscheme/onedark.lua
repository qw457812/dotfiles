return {
  -- disable built-in themes
  { "folke/tokyonight.nvim", cond = false },
  { "catppuccin/nvim", cond = false },

  -- add onedark
  {
    "navarasu/onedark.nvim",
    priority = 1000,
  },

  -- configure LazyVim to load onedark theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
