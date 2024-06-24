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
          -- https://github.com/RRethy/vim-illuminate#highlight-groups
          -- ~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_moon.lua
          -- #555555
          hl.IlluminatedWordRead = { bg = "#7e4c8b" }
          hl.IlluminatedWordText = { bg = "#7e4c8b" }
          hl.IlluminatedWordWrite = { bg = "#7e4c8b", underline = true }
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
