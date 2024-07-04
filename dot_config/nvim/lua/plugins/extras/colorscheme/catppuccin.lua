-- https://www.lazyvim.org/plugins/colorscheme#catppuccin
return {
  -- disable tokyonight
  -- { "folke/tokyonight.nvim", enabled = false },

  -- LazyVim already add catppuccin in ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/colorscheme.lua
  {
    "catppuccin/nvim",
    opts = {
      -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/mocha.lua
      custom_highlights = function(colors)
        -- highlight word/references under cursor
        -- require lazyvim.plugins.extras.editor.illuminate
        -- https://github.com/RRethy/vim-illuminate#highlight-groups
        -- colors.surface1(#45475a) #494d64 #51576d colors.surface2(#585b70)
        local illuminate = "#51576d"
        return {
          -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/integrations/illuminate.lua
          -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/syntax.lua
          -- IlluminatedWordText = { bg = colors.surface1 }, -- use default
          IlluminatedWordRead = { bg = illuminate },
          IlluminatedWordWrite = { bg = illuminate, underline = true },
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
