local to_neutral_gray = U.color.to_neutral_gray

local colorschemes = {
  -- "tokyonight", -- custom, `tokyonight-custom` not working
  "tokyonight-moon",
  "tokyonight-storm",
  "tokyonight-night",
  "catppuccin-frappe",
  "catppuccin-macchiato",
  "catppuccin-mocha",
  -- "onedark",
  -- "obscure",
}

-- :=vim.g.colors_name
local function random_colorscheme()
  local idx = tonumber(os.date("%S")) % #colorschemes + 1
  return colorschemes[idx]
end

local tokyonight_custom_style = "custom"

local function tokyonight_has_custom_style()
  return vim.list_contains(colorschemes, "tokyonight")
end

-- mark the style in colors, useful for `on_colors` and `on_highlights`
local function tokyonight_mark_style(colors, style)
  -- stylua: ignore
  if type(colors) ~= "table" then return end

  -- local styles = { [tokyonight_custom_style] = "#000000", moon = "#000001", storm = "#000002", night = "#000003" }
  local styles = { [tokyonight_custom_style] = "#000000" } -- only works for custom

  if style then
    -- set
    colors.style = styles[style]
  else
    -- get
    for k, v in pairs(styles) do
      -- stylua: ignore
      if colors.style == v then return k end
    end
  end
end

return {
  {
    "tokyonight.nvim",
    optional = true,
    opts = function()
      local util = require("tokyonight.util")
      return {
        style = tokyonight_has_custom_style() and tokyonight_custom_style or "storm", -- storm, moon(default), night, day, custom
        -- transparent = true,
        -- styles = {
        --   sidebars = "transparent",
        --   floats = "transparent",
        -- },
        -- ~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_storm.lua
        on_colors = function(c)
          -- more neutral background rather than bluish tint
          c.bg = to_neutral_gray(c.bg)
          c.bg_dark = to_neutral_gray(c.bg_dark)
          c.bg_float = c.bg_dark
          c.bg_highlight = to_neutral_gray(c.bg_highlight)
          c.bg_popup = c.bg_dark
          c.bg_sidebar = c.bg_dark
          c.bg_statusline = c.bg_dark

          -- gitcommit, mini.diff
          c.diff.add = util.blend_bg(c.green2, 0.35)
          c.diff.delete = util.blend_bg(c.red1, 0.35)
          c.diff.change = util.blend_bg(c.blue7, 0.35)

          if tokyonight_has_custom_style() and tokyonight_mark_style(c) == tokyonight_custom_style then
            c.bg_visual = c.dark3
          end
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

          hl.TelescopeSelectionCaret =
            { fg = (hl.TelescopePromptPrefix or hl.Identifier).fg, bg = (hl.TelescopeSelection or hl.Visual).bg }

          if tokyonight_has_custom_style() and tokyonight_mark_style(c) == tokyonight_custom_style then
            hl.String = { fg = c.orange }
            hl.Character = { fg = c.orange2 }
            hl.Function = { fg = c.yellow }
            hl["@variable.parameter"] = { fg = c.fg_bright }
            hl.Operator = { fg = c.magenta }
            hl["@operator"] = { fg = c.magenta }
            hl["@label.markdown"] = { link = "NonText" }
            hl["@markup.raw.delimiter.markdown"] = { link = "NonText" }

            hl.Search = { bg = hl.Search.bg, fg = util.blend_bg(hl.Search.fg, 0.15) }
            hl.Folded = { fg = c.blue, bg = c.bg_blue }
            hl.LineNr = { fg = c.dark5 }
            hl.LineNrAbove = { fg = c.dark5 }
            hl.LineNrBelow = { fg = c.dark5 }
            hl.CursorLineNr = { fg = c.fg_dark }
            hl.TelescopeSelection = { fg = c.fg_bright, bg = c.bg_highlight, bold = true }
            hl.TelescopeSelectionCaret = { fg = hl.TelescopeSelectionCaret.fg, bg = hl.TelescopeSelection.bg }
            hl.CmpItemKindSnippet = { fg = c.fg_bright }
            -- hl.PmenuThumb = { bg = c.border_highlight }
            -- hl.PmenuSel = { bg = c.bg_highlight, bold = true }
          end

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
    config = function(_, opts)
      if not tokyonight_has_custom_style() then
        require("tokyonight").setup(opts)
        return
      end

      -- https://github.com/folke/tokyonight.nvim/issues/595
      -- https://github.com/jdujava/nvim-jd/blob/ef39817500b7565dbd9978f54e83d21380c49c17/lua/plugins/colorscheme.lua#L86
      local styles = require("tokyonight.colors").styles

      -- change the colors for your new palette here
      -- stylua: ignore
      ---@type Palette
      local modified_colors = {
        bg_darker    = "#1a1a1a", --
        bg_dark      = "#1e1e1e",
        bg           = "#1e1e1e",
        dark2        = "#212121", --
        bg_context   = "#262626", --
        bg_highlight = "#2a2a2a",
        fg_gutter    = "#2a2a2a",
        bg_blue      = "#073642", --
        dark3        = "#3e4452",
        dark4        = "#454e53", --
        dark5        = "#5c6370",
        fg_bright    = "#f5ebd9", --
        fg_dark      = "#98a8b4",
        fg           = "#abb2bf",
        purple       = "#fca7ea",
        magenta      = "#c586c0",
        magenta2     = "#934669",
        blue0        = "#569cd6",
        blue         = "#7ecbff",
        cyan         = "#7dcfff",
        blue1        = "#6bafe5",
        blue2        = "#9cdcfe",
        blue5        = "#89ddff",
        blue6        = "#b4f9f8",
        blue7        = "#394b70",
        orange       = "#e6b089",
        orange2      = "#faa069", --
        yellow       = "#dcdcaa",
        green        = "#c3e88d",
        -- green1    = "#4ec9b0",
        green1       = "#89dcf4",
        green2       = "#2f563a",
        green3       = "#204533", --
        teal         = "#4ec9b0",
        comment      = "#608b4e",
      }

      tokyonight_mark_style(modified_colors, tokyonight_custom_style) -- for `on_colors` and `on_highlights` opts above

      -- save as `custom` style (by extending the `storm` style)
      styles[tokyonight_custom_style] = vim.tbl_extend("force", styles.storm --[[@as Palette]], modified_colors)

      -- load custom style (be sure to have opts.style = "custom")
      -- check `:=require("tokyonight.colors").setup({ style = "custom" })`
      -- https://github.com/folke/lazy.nvim/blob/077102c5bfc578693f12377846d427f49bc50076/lua/lazy/minit.lua#L90
      require("tokyonight").setup(opts)
      require("tokyonight").load()
    end,
  },

  -- https://github.com/aimuzov/LazyVimx/blob/af846de01acfaa78320d6564414c629e77d525e1/lua/lazyvimx/colorschemes/catppuccin.lua
  {
    "catppuccin/nvim",
    optional = true,
    opts = function(_, opts)
      local palettes = require("catppuccin.palettes")
      local frappe = palettes.get_palette("frappe")
      local macchiato = palettes.get_palette("macchiato")
      local mocha = palettes.get_palette("mocha")
      return vim.tbl_deep_extend("force", opts, {
        background = {
          dark = "macchiato", -- frappe, macchiato, mocha(default)
        },
        -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/macchiato.lua
        -- https://github.com/catppuccin/nvim/discussions/323
        -- https://github.com/tm157/dotfiles/blob/8a32eb599c4850a96a41a012fa3ba54c81111001/nvim/lua/user/colorscheme.lua#L31
        color_overrides = {
          frappe = {
            base = to_neutral_gray(frappe.base),
            mantle = to_neutral_gray(frappe.mantle),
            crust = to_neutral_gray(frappe.crust),
          },
          macchiato = {
            base = to_neutral_gray(macchiato.base),
            mantle = to_neutral_gray(macchiato.mantle),
            crust = to_neutral_gray(macchiato.crust),
          },
          mocha = {
            base = to_neutral_gray(mocha.base),
            mantle = to_neutral_gray(mocha.mantle),
            crust = to_neutral_gray(mocha.crust),
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
          local util = require("catppuccin.utils.colors")
          -- highlight word/references under cursor
          -- require lazyvim.plugins.extras.editor.illuminate
          -- colors.surface1(#45475a) #494d64 #51576d colors.surface2(#585b70)
          local illuminate = util.darken(colors.surface2, 0.8, colors.base)
          return {
            -- IlluminatedWordText = { bg = util.darken(colors.surface1, 0.7, colors.base) }, -- use default
            IlluminatedWordRead = { bg = illuminate },
            IlluminatedWordWrite = { bg = illuminate, style = { "underline" } },
            -- LspReferenceText = { bg = colors.surface1 }, -- use default
            LspReferenceRead = { link = "IlluminatedWordRead" },
            LspReferenceWrite = { link = "IlluminatedWordWrite" },
            -- compensate for invisible text caused by custom illuminate highlight
            CmpGhostText = { bg = colors.base, fg = colors.overlay1 },
            DiagnosticUnnecessary = { fg = util.lighten(colors.overlay0, 0.9) },
            -- require("tokyonight.colors").setup({style = "moon"}).bg_visual -- #2d3f76
            -- Visual = { bg = util.blend(colors.surface1, "#2d3f76", 0.25), style = { "bold" } },

            -- for flash treesitter search, not necessary after using `{ label = { rainbow = { enabled = true } } }` opts
            FlashLabel = { fg = colors.base, bg = colors.green, style = { "bold" } },

            TelescopePromptBorder = { fg = colors.peach },
            TelescopePromptTitle = { fg = colors.peach },
          }
        end,
      })
    end,
  },

  -- https://github.com/dhruvinsh/nvim/blob/bcc368b9e5013485fb01d46dfb2ea0037a2c9fc8/lua/orion/plugins/colors.lua#L9
  -- alternative: olimorris/onedarkpro.nvim | https://github.com/appelgriebsch/Nv/blob/e9a584090a69a8d691f5eb051e76016b65dfc0b7/lua/plugins/extras/ui/onedarkpro-theme.lua
  {
    "navarasu/onedark.nvim",
    cond = vim.list_contains(colorschemes, "onedark"),
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
          -- require("tokyonight.colors").setup({style = "moon"}).bg_visual -- #2d3f76
          -- Visual = { bg = util.blend(colors.bg3, "#2d3f76", 0.25) },
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
    "killitar/obscure.nvim",
    cond = vim.list_contains(colorschemes, "obscure"),
    lazy = true,
    opts = function()
      local p = require("obscure.palettes").get_palette("obscure")
      -- ~/.local/share/nvim/lazy/obscure.nvim/lua/obscure/palettes/obscure.lua
      local illuminate = p.gray4
      return {
        highlight_overrides = {
          IlluminatedWordText = { bg = p.gray3 },
          IlluminatedWordRead = { bg = illuminate },
          IlluminatedWordWrite = { bg = illuminate, underline = true },
          LspReferenceRead = { bg = illuminate },
          LspReferenceWrite = { bg = illuminate, underline = true },

          Conceal = { fg = p.subtext4 }, -- for DropBarFolderName
          Search = { fg = p.bright_yellow, bg = p.subtext4 },

          FlashLabel = { fg = p.bg, bg = p.bright_green, bold = true },

          TelescopePromptBorder = { fg = p.yellow },
          TelescopePromptTitle = { fg = p.yellow },
          TelescopeResultsTitle = { fg = p.blue },
          TelescopePreviewTitle = { fg = p.blue },
          TelescopeBorder = { fg = p.blue },

          MiniIndentscopeSymbol = { fg = p.subtext2 },
        },
      }
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = random_colorscheme(),
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = function(_, keys)
      if LazyVim.pick.picker.name == "telescope" then
        table.insert(keys, {
          "<leader>uC",
          function()
            require("telescope.builtin").colorscheme({
              colors = colorschemes,
              enable_preview = true,
              ignore_builtins = true,
            })
          end,
          desc = "Colorscheme with Preview",
        })
      end
    end,
  },
}
