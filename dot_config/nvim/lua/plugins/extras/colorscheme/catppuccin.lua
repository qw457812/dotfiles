-- https://github.com/aimuzov/LazyVimx/blob/af846de01acfaa78320d6564414c629e77d525e1/lua/lazyvimx/colorschemes/catppuccin.lua
return {
  -- { "folke/tokyonight.nvim", cond = false },

  {
    "catppuccin/nvim",
    opts = {
      -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/mocha.lua
      custom_highlights = function(colors)
        local U = require("catppuccin.utils.colors")
        -- highlight word/references under cursor
        -- require lazyvim.plugins.extras.editor.illuminate
        -- colors.surface1(#45475a) #494d64 #51576d colors.surface2(#585b70)
        local illuminate = U.darken(colors.surface2, 0.8, colors.base)
        return {
          -- IlluminatedWordText = { bg = U.darken(colors.surface1, 0.7, colors.base) }, -- use default
          IlluminatedWordRead = { bg = illuminate },
          IlluminatedWordWrite = { bg = illuminate, underline = true },
          -- LspReferenceText = { bg = colors.surface1 }, -- use default
          LspReferenceRead = { link = "IlluminatedWordRead" },
          LspReferenceWrite = { link = "IlluminatedWordWrite" },
          -- compensate for invisible text caused by custom illuminate highlight
          CmpGhostText = { bg = colors.base, fg = colors.overlay1 },
          DiagnosticUnnecessary = { fg = U.lighten(colors.overlay0, 0.9) },
        }
      end,
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
