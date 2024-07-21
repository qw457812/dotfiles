-- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/plugins/colorscheme.lua
return {
  -- disable built-in themes
  { "folke/tokyonight.nvim", cond = false },
  { "catppuccin/nvim", cond = false },

  -- add solarized-osaka
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

  -- configure LazyVim to load solarized-osaka theme
  -- https://github.com/craftzdog/dotfiles-public/blob/bf837d867b1aa153cbcb2e399413ec3bdcce112b/.config/nvim/lua/config/lazy.lua#L21
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "solarized-osaka",
    },
  },
}
