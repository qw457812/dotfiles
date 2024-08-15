return {
  {
    "tokyonight.nvim",
    optional = true,
    opts = function()
      return {
        style = "storm", -- storm, moon(default), night, day
        -- transparent = true,
        -- styles = {
        --   sidebars = "transparent",
        --   floats = "transparent",
        -- },
        -- ~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_storm.lua
        on_highlights = function(hl, c)
          local util = require("tokyonight.util")
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
        dark = "frappe", -- frappe, macchiato, mocha(default)
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
      -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/frappe.lua
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

          -- for flash treesitter search, not necessary after using `{ label = { rainbow = { enabled = true } } }` opts
          FlashLabel = { fg = colors.base, bg = colors.green, style = { "bold" } },
        }
      end,
    },
  },
}
