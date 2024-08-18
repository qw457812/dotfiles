local style = "dark" -- dark(default), darker, cool, deep, warm, warmer, light

return {
  -- { "folke/tokyonight.nvim", cond = false },
  -- { "catppuccin/nvim", cond = false },

  -- https://github.com/dhruvinsh/nvim/blob/bcc368b9e5013485fb01d46dfb2ea0037a2c9fc8/lua/orion/plugins/colors.lua#L9
  {
    "navarasu/onedark.nvim",
    priority = 1000,
    lazy = true,
    opts = function()
      local util = require("onedark.util")
      local colors = require("onedark.palette")[style]

      local illuminate = util.darken(colors.grey, 0.8)
      return {
        style = style,
        -- ~/.local/share/nvim/lazy/onedark.nvim/lua/onedark/palette.lua
        highlights = {
          IlluminatedWordRead = { bg = illuminate },
          IlluminatedWordWrite = { bg = illuminate, fmt = "underline" },
          CmpGhostText = { bg = "$bg0", fg = "$grey", fmt = "italic" },
          DiagnosticUnnecessary = { fg = util.lighten(colors.grey, 0.7), fmt = "italic" },
          -- TelescopePromptTitle = { bg = "$dark_cyan", fg = "white", fmt = "bold" },
          -- TelescopeResultsTitle = { bg = "$dark_purple", fg = "white", fmt = "bold" },
          -- TelescopePreviewTitle = { bg = "$dark_red", fg = "white", fmt = "bold" },
        },
      }
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
