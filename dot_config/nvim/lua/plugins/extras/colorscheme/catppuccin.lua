-- https://www.lazyvim.org/plugins/colorscheme#catppuccin
return {
  -- disable tokyonight
  { "folke/tokyonight.nvim", cond = false },

  -- LazyVim already add catppuccin in ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/colorscheme.lua
  {
    "catppuccin/nvim",
    opts = {
      -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/mocha.lua
      custom_highlights = function(colors)
        local darken = require("catppuccin.utils.colors").darken
        -- highlight word/references under cursor
        -- require lazyvim.plugins.extras.editor.illuminate
        -- https://github.com/RRethy/vim-illuminate#highlight-groups
        -- https://github.com/aimuzov/LazyVimx/blob/af846de01acfaa78320d6564414c629e77d525e1/lua/lazyvimx/colorschemes/catppuccin.lua#L151
        -- local illuminate = darken(colors.sapphire, 0.25, colors.base)
        -- colors.surface1(#45475a) #494d64 #51576d colors.surface2(#585b70)
        local illuminate = darken(colors.surface2, 0.8, colors.base)
        return {
          -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/integrations/illuminate.lua
          -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/syntax.lua
          -- IlluminatedWordText = { bg = darken(colors.surface1, 0.7, colors.base) }, -- use default
          IlluminatedWordRead = { bg = illuminate },
          IlluminatedWordWrite = { bg = illuminate, underline = true },
          -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/integrations/native_lsp.lua
          -- LspReferenceText = { bg = colors.surface1 }, -- use default
          LspReferenceRead = { link = "IlluminatedWordRead" },
          LspReferenceWrite = { link = "IlluminatedWordWrite" },
          -- compensate for invisible text caused by custom illuminate highlight
          -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/integrations/cmp.lua
          CmpGhostText = { bg = colors.base, fg = colors.overlay1 },
        }
      end,
    },
  },

  -- configure LazyVim to load catppuccin theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
