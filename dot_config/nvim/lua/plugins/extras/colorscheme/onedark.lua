return {
  { "folke/tokyonight.nvim", cond = false },
  { "catppuccin/nvim", cond = false },

  {
    "navarasu/onedark.nvim",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
