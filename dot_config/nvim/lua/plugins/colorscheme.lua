-- see: ~/.config/nvim/lua/plugins/extras/colorscheme/
return {
  -- https://github.com/folke/dot/blob/master/nvim/lua/plugins/colorscheme.lua
  -- https://www.lazyvim.org/configuration/recipes#make-tokyonight-transparent
  {
    "tokyonight.nvim",
    opts = function()
      return {
        style = "moon",
        -- transparent = true,
        -- styles = {
        --   sidebars = "transparent",
        --   floats = "transparent",
        -- },
        sidebars = {
          "qf",
          "vista_kind",
          -- "terminal",
          "spectre_panel",
          "startuptime",
          "Outline",
        },
        on_highlights = function(hl, c)
          -- highlight word/references under cursor
          -- https://github.com/RRethy/vim-illuminate#highlight-groups
          -- ~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_moon.lua
          -- #7847bd #8552a1 #7e4c8b #731d8b
          -- #188092 #35717b #007197 #006a83 #265b75
          -- #555555 #5b6078 #585b70 #51576d #494d64
          -- #3760bf
          hl.IlluminatedWordRead = { bg = "#51576d" }
          hl.IlluminatedWordText = { bg = "#3b4261" }
          hl.IlluminatedWordWrite = { bg = "#51576d", underline = true }

          do
            return
          end
          local prompt = "#2d3149"
          hl.TelescopeNormal = { bg = c.bg_dark, fg = c.fg }
          hl.TelescopeBorder = { bg = c.bg_dark, fg = c.bg_dark }
          hl.TelescopePromptNormal = { bg = prompt }
          hl.TelescopePromptBorder = { bg = prompt, fg = prompt }
          hl.TelescopePromptTitle = { bg = c.fg_gutter, fg = c.orange }
          hl.TelescopePreviewTitle = { bg = c.bg_dark, fg = c.bg_dark }
          hl.TelescopeResultsTitle = { bg = c.bg_dark, fg = c.bg_dark }
        end,
      }
    end,
  },

  -- -- https://www.lazyvim.org/plugins/colorscheme
  -- -- add gruvbox
  -- { "ellisonleao/gruvbox.nvim" },
  -- -- configure LazyVim to load gruvbox
  -- {
  --   "LazyVim/LazyVim",
  --   opts = {
  --     colorscheme = "gruvbox",
  --   },
  -- },
}
