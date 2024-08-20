local function randomColorScheme()
  local themes = {
    "tokyonight-moon",
    "tokyonight-storm",
    -- "tokyonight-night", -- similar to `tokyonight-storm` after `on_colors` opt
    "catppuccin-frappe",
    "catppuccin-macchiato",
    "catppuccin-mocha",
    "onedark",
  }
  local idx = tonumber(os.date("%S")) % #themes + 1
  local colorscheme = themes[idx]
  LazyVim.info(colorscheme, { title = "Random ColorScheme" })
  return colorscheme
end

return {
  {
    "tokyonight.nvim",
    optional = true,
    opts = function()
      local util = require("tokyonight.util")
      return {
        style = "storm", -- storm, moon(default), night, day
        -- transparent = true,
        -- styles = {
        --   sidebars = "transparent",
        --   floats = "transparent",
        -- },
        -- ~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_storm.lua
        on_colors = function(c)
          -- more neutral background rather than bluish tint
          c.bg = "#242424" -- #24283b
          c.bg_dark = "#1f1f1f" -- #1f2335
          c.bg_float = c.bg_dark
          c.bg_highlight = "#292929" -- #292e42
          c.bg_popup = c.bg_dark
          c.bg_sidebar = c.bg_dark
          c.bg_statusline = c.bg_dark

          -- gitcommit, mini.diff
          c.diff.add = util.blend(c.diff.add, 0.925, c.git.add)
          c.diff.change = util.blend(c.diff.change, 0.925, c.git.change)
          c.diff.delete = util.blend(c.diff.delete, 0.925, c.git.delete)
          c.diff.text = util.blend(c.diff.text, 0.925, c.git.ignore)
        end,
        on_highlights = function(hl, c)
          -- highlight word/references under cursor
          -- require lazyvim.plugins.extras.editor.illuminate
          -- #5b6078 #585b70 #51576d #494d64 #45475a
          -- util.blend_bg("#585b70", 0.85)
          local illuminate = util.blend_fg(hl.IlluminatedWordRead.bg, 0.875)
          -- hl.IlluminatedWordText = { bg = "#3b4261" } -- use default
          hl.IlluminatedWordRead = { bg = illuminate }
          hl.IlluminatedWordWrite = { bg = illuminate, underline = true }
          -- see `:h lsp-highlight`
          -- hl.LspReferenceText = { bg = "#3b4261" } -- use default
          hl.LspReferenceRead = { link = "IlluminatedWordRead" }
          hl.LspReferenceWrite = { link = "IlluminatedWordWrite" }
          -- compensate for invisible text caused by custom illuminate highlight
          hl.CmpGhostText = { bg = c.bg, fg = util.blend_fg(hl.CmpGhostText.fg, 0.85) }
          -- unused variable
          hl.DiagnosticUnnecessary = { fg = util.blend_fg(c.terminal_black, 0.7) }

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

  -- https://github.com/aimuzov/LazyVimx/blob/af846de01acfaa78320d6564414c629e77d525e1/lua/lazyvimx/colorschemes/catppuccin.lua
  {
    "catppuccin/nvim",
    optional = true,
    opts = {
      background = {
        dark = "macchiato", -- frappe, macchiato, mocha(default)
      },
      -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/macchiato.lua
      -- https://github.com/catppuccin/nvim/discussions/323
      -- https://github.com/tm157/dotfiles/blob/8a32eb599c4850a96a41a012fa3ba54c81111001/nvim/lua/user/colorscheme.lua#L31
      color_overrides = {
        frappe = {
          base = "#303030", -- #303446
          mantle = "#292929", -- #292c3c
          crust = "#232323", -- #232634
        },
        macchiato = {
          base = "#242424", -- #24273a
          mantle = "#1e1e1e", -- #1e2030
          crust = "#181818", -- #181926
        },
        mocha = {
          base = "#1e1e1e", -- #1e1e2e
          mantle = "#181818", -- #181825
          crust = "#111111", -- #11111b
        },
      },
      integrations = {
        mini = {
          enabled = true,
          indentscope_color = "subtext0",
        },
        dropbar = {
          enabled = true,
          -- color_mode = true,
        },
      },
      custom_highlights = function(colors)
        local U = require("catppuccin.utils.colors")
        -- highlight word/references under cursor
        -- require lazyvim.plugins.extras.editor.illuminate
        -- colors.surface1(#45475a) #494d64 #51576d colors.surface2(#585b70)
        local illuminate = U.darken(colors.surface2, 0.8, colors.base)
        return {
          -- IlluminatedWordText = { bg = U.darken(colors.surface1, 0.7, colors.base) }, -- use default
          IlluminatedWordRead = { bg = illuminate },
          IlluminatedWordWrite = { bg = illuminate, style = { "underline" } },
          -- LspReferenceText = { bg = colors.surface1 }, -- use default
          LspReferenceRead = { link = "IlluminatedWordRead" },
          LspReferenceWrite = { link = "IlluminatedWordWrite" },
          -- compensate for invisible text caused by custom illuminate highlight
          CmpGhostText = { bg = colors.base, fg = colors.overlay1 },
          DiagnosticUnnecessary = { fg = U.lighten(colors.overlay0, 0.9) },
          -- Visual = { bg = U.blend(colors.surface1, "#2d3f76", 0.25), style = { "bold" } }, -- from tokyonight-moon

          -- for flash treesitter search, not necessary after using `{ label = { rainbow = { enabled = true } } }` opts
          FlashLabel = { fg = colors.base, bg = colors.green, style = { "bold" } },

          TelescopePromptBorder = { fg = colors.peach },
          TelescopePromptTitle = { fg = colors.peach },
        }
      end,
    },
  },

  -- https://github.com/dhruvinsh/nvim/blob/bcc368b9e5013485fb01d46dfb2ea0037a2c9fc8/lua/orion/plugins/colors.lua#L9
  -- alternative: olimorris/onedarkpro.nvim | https://github.com/appelgriebsch/Nv/blob/e9a584090a69a8d691f5eb051e76016b65dfc0b7/lua/plugins/extras/ui/onedarkpro-theme.lua
  {
    "navarasu/onedark.nvim",
    lazy = true,
    opts = function()
      local style = "dark" -- dark(default), darker, cool, deep, warm, warmer, light
      local util = require("onedark.util")
      local colors = require("onedark.palette")[style]
      local illuminate = util.darken(colors.grey, 0.8)
      return {
        style = style,
        -- ~/.local/share/nvim/lazy/onedark.nvim/lua/onedark/palette.lua
        highlights = {
          IlluminatedWordRead = { bg = illuminate },
          IlluminatedWordWrite = { bg = illuminate, fmt = "underline" },
          LspReferenceRead = { bg = illuminate },
          LspReferenceWrite = { bg = illuminate, fmt = "underline" },
          CmpGhostText = { bg = "$bg0", fg = "$grey", fmt = "italic" },
          DiagnosticUnnecessary = { fg = util.lighten(colors.grey, 0.7), fmt = "italic" },
          MatchParen = { bg = "$grey", fg = "$orange", fmt = "bold" }, -- for LazyVim.lualine.pretty_path() and DropBarFileNameModified
          -- Visual = { bg = util.blend(colors.bg3, "#2d3f76", 0.25) }, -- from tokyonight-moon
          Visual = { bg = util.lighten(colors.bg3, 0.975), fmt = "bold" },

          NeoTreeEndOfBuffer = { bg = "none" },

          TelescopePromptBorder = { fg = "$orange" },
          TelescopePromptTitle = { fg = "$orange" },
          TelescopeResultsTitle = { fg = "$cyan" },
          TelescopePreviewTitle = { fg = "$cyan" },
        },
      }
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = randomColorScheme(),
    },
  },
}
