-- tokyonight (custom style, `tokyonight-custom` not working)
-- tokyonight-moon
-- tokyonight-storm
-- tokyonight-night
-- catppuccin-frappe
-- catppuccin-macchiato
-- catppuccin-mocha
-- neon-punkpeach-storm
-- neon-punkpeach-night
-- onedark
-- obscure
-- cyberdream
local colorschemes = vim.g.user_transparent_background and {
  "tokyonight-moon",
  "catppuccin-frappe",
} or {
  "tokyonight-moon",
  "tokyonight-storm",
  "catppuccin-macchiato",
}
local has_tokyonight_custom_style = vim.list_contains(colorschemes, "tokyonight")
-- for picker
local ignored_colorschemes = vim.list_extend({
  "tokyonight-day",
  "catppuccin", -- redundant with catppuccin-macchiato
  "catppuccin-latte",
}, has_tokyonight_custom_style and {} or { "tokyonight" })

-- options
local borderless_telescope = false -- vim.g.user_transparent_background
local no_italic = vim.g.user_is_termux

local tokyonight_custom_style = "custom"

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

-- https://github.com/Styzex/RandTheme.nvim/blob/f96818619d9dcfa179f6d15eb67b04cae6ed31c7/lua/randtheme/theme_manager.lua#L62
local last_random ---@type string?
---@return string?
local function random_colorscheme()
  local themes = vim.tbl_filter(function(v)
    -- vim.fn.execute("colorscheme")
    return v ~= last_random and v ~= vim.g.colors_name
  end, colorschemes)
  if #themes == 0 then
    return nil
  end
  -- return themes[tonumber(os.date("%S")) % #themes + 1]
  -- generate random config with initialized random seed (otherwise it won't be random during startup)
  math.randomseed(vim.uv.hrtime())
  local random = themes[math.random(#themes)]
  last_random = random
  return random
end

local function cond_colorscheme(pattern)
  for _, c in ipairs(colorschemes) do
    if c:match(pattern) then
      return true
    end
  end
  return false
end

local function to_gray(color)
  -- transparent: CursorLine
  return vim.g.user_transparent_background and color or require("util.color").to_gray(color)
end

return {
  {
    "tokyonight.nvim",
    optional = true,
    opts = function()
      local util = require("tokyonight.util")
      return {
        style = has_tokyonight_custom_style and tokyonight_custom_style or "storm", -- storm, moon(default), night, day, custom
        transparent = vim.g.user_transparent_background,
        styles = {
          comments = { italic = not no_italic },
          keywords = { italic = not no_italic },
          sidebars = vim.g.user_transparent_background and "transparent" or nil,
          floats = vim.g.user_transparent_background and "transparent" or nil,
        },
        -- ~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_storm.lua
        on_colors = function(c)
          -- more neutral background rather than bluish tint
          c.bg = to_gray(c.bg)
          c.bg_dark = to_gray(c.bg_dark)
          c.bg_float = to_gray(c.bg_float)
          c.bg_highlight = to_gray(c.bg_highlight)
          c.bg_popup = to_gray(c.bg_popup)
          c.bg_sidebar = to_gray(c.bg_sidebar)
          c.bg_statusline = to_gray(c.bg_statusline)

          -- gitcommit, mini.diff
          c.diff.add = util.blend_bg(c.green2, 0.35)
          c.diff.delete = util.blend_bg(c.red1, 0.35)
          c.diff.change = util.blend_bg(c.blue7, 0.35)

          if has_tokyonight_custom_style and tokyonight_mark_style(c) == tokyonight_custom_style then
            c.bg_visual = c.dark3
          end
        end,
        on_highlights = function(hl, c)
          -- highlight word/references under cursor
          -- require lazyvim.plugins.extras.editor.illuminate
          -- #5b6078 #585b70 #51576d #494d64 #45475a
          -- util.blend_bg("#585b70", 0.85)
          local illuminate = util.blend_fg(hl.IlluminatedWordRead and hl.IlluminatedWordRead.bg or "#3b4261", 0.875)
          -- hl.IlluminatedWordText = { bg = "#3b4261" } -- use default
          hl.IlluminatedWordRead = { bg = illuminate }
          hl.IlluminatedWordWrite = { bg = illuminate, underline = true }
          -- see `:h lsp-highlight`
          -- hl.LspReferenceText = { bg = "#3b4261" } -- use default
          hl.LspReferenceRead = { link = "IlluminatedWordRead" }
          hl.LspReferenceWrite = { link = "IlluminatedWordWrite" }
          -- compensate for invisible text caused by custom illuminate highlight
          -- -- not necessary after disabling vim-illuminate in insert mode
          -- hl.CmpGhostText = {
          --   -- bg = vim.g.user_transparent_background and "#000000" or c.bg,
          --   bg = c.bg,
          --   fg = util.blend_fg((hl.CmpGhostText or hl.Comment).fg, vim.g.user_transparent_background and 0.5 or 0.85),
          -- }
          -- hl.BlinkCmpGhostText = { link = "CmpGhostText" }
          -- unused variable
          hl.DiagnosticUnnecessary = { fg = util.blend_fg(c.terminal_black, 0.7) }

          hl.TelescopeSelectionCaret =
            { fg = (hl.TelescopePromptPrefix or hl.Identifier).fg, bg = (hl.TelescopeSelection or hl.Visual).bg }

          if borderless_telescope then
            local bg = to_gray(c.bg_dark) -- c.bg_dark
            local prompt = bg -- "#2d3149"
            hl.TelescopeNormal = { bg = bg, fg = c.fg }
            hl.TelescopeBorder = { bg = bg, fg = bg }
            hl.TelescopePromptNormal = { bg = prompt }
            hl.TelescopePromptBorder = { bg = prompt, fg = prompt }
            -- -- hl.TelescopePromptTitle = { bg = c.fg_gutter, fg = c.orange }
            -- hl.TelescopePromptTitle = { bg = prompt, fg = c.orange }
            -- hl.TelescopePreviewTitle = { bg = bg, fg = bg }
            -- hl.TelescopeResultsTitle = { bg = bg, fg = bg }
            -- cyberdream flat style: https://github.com/scottmckendry/cyberdream.nvim/blob/28cde1cf8b792e6dffe51f0d98632b361baa972b/lua/cyberdream/extensions/telescope.lua#L40
            hl.TelescopePromptTitle = { fg = c.black, bg = util.blend_bg(c.red, 0.8), bold = true }
            hl.TelescopePreviewTitle = { fg = c.black, bg = util.blend_bg(c.green, 0.75), bold = true }
            hl.TelescopeResultsTitle = { fg = util.blend_bg(c.red, 0.8), bg = bg, bold = true }
          end

          if not vim.g.user_transparent_background then
            hl.NeoTreeWinSeparator = { fg = c.bg, bg = c.bg }
          end

          if has_tokyonight_custom_style and tokyonight_mark_style(c) == tokyonight_custom_style then
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
            hl.TelescopeSelectionCaret = U.extend_tbl(hl.TelescopeSelectionCaret, { bg = hl.TelescopeSelection.bg })
            hl.CmpItemKindSnippet = { fg = c.fg_bright }
            -- hl.PmenuThumb = { bg = c.border_highlight }
            -- hl.PmenuSel = { bg = c.bg_highlight, bold = true }
          end
        end,
      }
    end,
    config = function(_, opts)
      if not has_tokyonight_custom_style then
        require("tokyonight").setup(opts)
        return
      end

      -- https://github.com/folke/tokyonight.nvim/issues/595
      -- https://github.com/jdujava/nvim-jd/blob/ef39817500b7565dbd9978f54e83d21380c49c17/lua/plugins/colorscheme.lua#L86
      local styles = require("tokyonight.colors").styles

      -- change the colors for your new palette here
      -- stylua: ignore
      ---@type Palette
      ---@diagnostic disable-next-line: missing-fields
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
    "catppuccin",
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
        transparent_background = vim.g.user_transparent_background,
        no_italic = no_italic,
        integrations = {
          mini = {
            enabled = true,
            -- indentscope_color = "subtext0",
          },
          dropbar = {
            enabled = true,
            -- color_mode = true,
          },
          -- telescope = {
          --   enabled = true,
          --   style = borderless_telescope and "nvchad" or nil, -- not working when transparent
          -- },
          treesitter_context = false,
        },
        -- ~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/macchiato.lua
        -- https://github.com/catppuccin/nvim/discussions/323
        -- https://github.com/tm157/dotfiles/blob/8a32eb599c4850a96a41a012fa3ba54c81111001/nvim/lua/user/colorscheme.lua#L31
        color_overrides = {
          frappe = {
            base = to_gray(frappe.base),
            mantle = to_gray(frappe.mantle),
            crust = to_gray(frappe.crust),
          },
          macchiato = {
            base = to_gray(macchiato.base),
            mantle = to_gray(macchiato.mantle),
            crust = to_gray(macchiato.crust),
          },
          mocha = {
            base = to_gray(mocha.base),
            mantle = to_gray(mocha.mantle),
            crust = to_gray(mocha.crust),
          },
        },
        custom_highlights = function(colors)
          local util = require("catppuccin.utils.colors")
          -- highlight word/references under cursor
          -- require lazyvim.plugins.extras.editor.illuminate
          -- colors.surface1(#45475a) #494d64 #51576d colors.surface2(#585b70)
          local illuminate = util.darken(colors.surface2, 0.8, colors.base)
          local indent_scope = util.blend(colors.green, colors.sapphire, 0.75)
          local custom_highlights = {
            -- IlluminatedWordText = { bg = util.darken(colors.surface1, 0.7, colors.base) }, -- use default
            IlluminatedWordRead = { bg = illuminate },
            IlluminatedWordWrite = { bg = illuminate, style = { "underline" } },
            -- LspReferenceText = { bg = colors.surface1 }, -- use default
            LspReferenceRead = { link = "IlluminatedWordRead" },
            LspReferenceWrite = { link = "IlluminatedWordWrite" },
            -- compensate for invisible text caused by custom illuminate highlight
            -- -- not necessary after disabling vim-illuminate in insert mode
            -- CmpGhostText = {
            --   -- bg = vim.g.user_transparent_background and "#000000" or colors.base,
            --   bg = colors.base,
            --   fg = vim.g.user_transparent_background and util.lighten(colors.overlay1, 0.875) or colors.overlay1,
            -- },
            -- BlinkCmpGhostText = { link = "CmpGhostText" },
            DiagnosticUnnecessary = { fg = util.lighten(colors.overlay0, 0.9) },
            -- revert https://github.com/catppuccin/nvim/pull/768
            Comment = { fg = colors.overlay0, style = { "italic" } },
            -- require("tokyonight.colors").setup({style = "moon"}).bg_visual -- #2d3f76
            -- Visual = { bg = util.blend(colors.surface1, "#2d3f76", 0.25), style = { "bold" } },

            TreesitterContext = {
              bg = vim.g.user_transparent_background and util.darken(colors.surface0, 0.5, colors.base)
                or util.darken(colors.surface1, 0.7, colors.base),
            },

            MiniIndentscopeSymbol = { fg = indent_scope },
            SnacksIndent = { fg = colors.surface0, style = { "nocombine" } }, -- IblIndent
            SnacksIndentScope = { fg = indent_scope, style = { "nocombine" } },

            -- for flash treesitter search, not necessary after using `{ label = { rainbow = { enabled = true } } }` opts
            FlashLabel = { fg = colors.base, bg = colors.green, style = { "bold" } },

            -- highlight-undo.nvim
            HighlightUndo = { link = "CurSearch" },
            HighlightRedo = { link = "HighlightUndo" },

            TelescopeSelection = { fg = colors.text, bg = colors.surface0, style = { "bold" } },
            TelescopeSelectionCaret = { fg = colors.flamingo, bg = colors.surface0 },
          }

          if vim.g.user_transparent_background then
            custom_highlights = vim.tbl_deep_extend("force", custom_highlights, {
              VertSplit = { fg = colors.crust },
              NeoTreeVertSplit = { link = "VertSplit" },
              WinSeparator = { fg = colors.crust, style = { "bold" } },
              NeoTreeWinSeparator = { link = "WinSeparator" },
            })
          end

          local borderless_telescope_bg = to_gray(colors.mantle)
          return vim.tbl_deep_extend("force", custom_highlights, borderless_telescope and {
            -- copied from: https://github.com/catppuccin/nvim/blob/35d8057137af463c9f41f169539e9b190d57d269/lua/catppuccin/groups/integrations/telescope.lua#L6
            TelescopeBorder = { fg = borderless_telescope_bg, bg = borderless_telescope_bg },
            TelescopeNormal = { bg = borderless_telescope_bg },
            -- TelescopePromptBorder = { fg = colors.surface0, bg = colors.surface0 },
            -- TelescopePromptNormal = { fg = colors.text, bg = colors.surface0 },
            TelescopePromptBorder = { fg = borderless_telescope_bg, bg = borderless_telescope_bg },
            TelescopePromptNormal = { fg = colors.text, bg = borderless_telescope_bg },
            -- TelescopePromptPrefix = { fg = colors.flamingo, bg = colors.surface0 },
            TelescopePreviewTitle = { fg = colors.base, bg = colors.green },
            TelescopePromptTitle = { fg = colors.base, bg = colors.red },
            -- TelescopeResultsTitle = { fg = borderless_telescope_bg, bg = colors.lavender },
            TelescopeResultsTitle = { fg = colors.red, bg = borderless_telescope_bg },
          } or {
            TelescopePromptBorder = { fg = colors.peach },
            TelescopePromptTitle = { fg = colors.peach },
            TelescopeBorder = { fg = colors.sapphire },
          })
        end,
      })
    end,
  },

  -- variants of tokyonight
  {
    "Zeioth/neon.nvim",
    enabled = false,
    cond = cond_colorscheme("^neon"),
    lazy = true,
    opts = function()
      local util = require("neon.util")
      return {
        transparent = vim.g.user_transparent_background,
        styles = {
          sidebars = vim.g.user_transparent_background and "transparent" or nil,
          floats = vim.g.user_transparent_background and "transparent" or nil,
        },
        -- ~/.local/share/nvim/lazy/neon.nvim/lua/neon/colors/punkpeach-storm.lua
        on_colors = function(c)
          c.bg = to_gray(c.bg)
          c.bg_dark = to_gray(c.bg_dark)
          c.bg_float = to_gray(c.bg_float)
          c.bg_highlight = to_gray(c.bg_highlight)
          c.bg_popup = to_gray(c.bg_popup)
          c.bg_sidebar = to_gray(c.bg_sidebar)
          c.bg_statusline = to_gray(c.bg_statusline)

          -- gitcommit, mini.diff
          c.diff.add = util.blend_bg(c.green2, 0.35)
          c.diff.delete = util.blend_bg(c.red1, 0.35)
          c.diff.change = util.blend_bg(c.blue7, 0.35)

          c.green1 = util.blend_bg(c.green1, 0.9)
        end,
        on_highlights = function(hl, c)
          local illuminate = util.blend_fg(hl.IlluminatedWordRead.bg, 0.875)
          hl.IlluminatedWordRead = { bg = illuminate }
          hl.IlluminatedWordWrite = { bg = illuminate, underline = true }
          hl.LspReferenceRead = { link = "IlluminatedWordRead" }
          hl.LspReferenceWrite = { link = "IlluminatedWordWrite" }
          -- hl.CmpGhostText = { bg = c.bg, fg = util.blend_fg((hl.CmpGhostText or hl.Comment).fg, 0.85) }
          hl.DiagnosticUnnecessary = { fg = util.blend_fg(c.terminal_black, 0.7) }

          hl.TelescopeSelectionCaret =
            { fg = (hl.TelescopePromptPrefix or hl.Identifier).fg, bg = (hl.TelescopeSelection or hl.Visual).bg }
        end,
      }
    end,
  },

  -- https://github.com/dhruvinsh/nvim/blob/bcc368b9e5013485fb01d46dfb2ea0037a2c9fc8/lua/orion/plugins/colors.lua#L9
  -- alternative: olimorris/onedarkpro.nvim | https://github.com/appelgriebsch/Nv/blob/e9a584090a69a8d691f5eb051e76016b65dfc0b7/lua/plugins/extras/ui/onedarkpro-theme.lua
  {
    "navarasu/onedark.nvim",
    enabled = false,
    cond = cond_colorscheme("^onedark$"),
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
          -- CmpGhostText = { bg = "$bg0", fg = "$grey", fmt = "italic" },
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
    enabled = false,
    cond = cond_colorscheme("^obscure$"),
    lazy = true,
    opts = function()
      local util = require("obscure.util")
      -- ~/.local/share/nvim/lazy/obscure.nvim/lua/obscure/palettes/obscure.lua
      return {
        on_highlights = function(hl, c)
          local illuminate = util.lighten(c.gray4, 0.925, c.fg)
          hl.IlluminatedWordText = { bg = c.gray3 }
          hl.IlluminatedWordRead = { bg = illuminate }
          hl.IlluminatedWordWrite = { bg = illuminate, underline = true }
          hl.LspReferenceRead = { bg = illuminate }
          hl.LspReferenceWrite = { bg = illuminate, underline = true }

          hl.Conceal = { fg = c.subtext4 } -- for DropBarFolderName
          hl.Search = { fg = c.bright_yellow, bg = c.subtext4 }

          hl.FlashLabel = { fg = c.bg, bg = c.bright_green, bold = true }

          hl.TelescopePromptBorder = { fg = c.yellow }
          hl.TelescopePromptTitle = { fg = c.yellow }
          hl.TelescopeResultsTitle = { fg = c.blue }
          hl.TelescopePreviewTitle = { fg = c.blue }
          hl.TelescopeBorder = { fg = c.blue }

          hl.MiniIndentscopeSymbol = { fg = c.subtext2, nocombine = true }
        end,
      }
    end,
  },

  {
    "scottmckendry/cyberdream.nvim",
    enabled = false,
    cond = cond_colorscheme("^cyberdream$"),
    lazy = true,
    dependencies = { "nvim-lualine/lualine.nvim", optional = true },
    init = function()
      local lualine_sep_orig
      local is_lualine_modified = false
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function(event)
          -- https://github.com/scottmckendry/cyberdream.nvim/blob/7e6feb49d2ec47a742215754ec0ecc51eebba55a/lua/cyberdream/util.lua#L257
          local ok, lualine = pcall(require, "lualine")
          if not ok then
            return
          end

          local lualine_opts = lualine.get_config()
          if event.match == "cyberdream" and vim.g.user_transparent_background then
            lualine_sep_orig = lualine_sep_orig or lualine_opts.options.section_separators
            lualine_opts.options.section_separators = { left = "", right = "" }
            is_lualine_modified = true
          elseif is_lualine_modified then
            lualine_opts.options.section_separators = lualine_sep_orig
          else
            return
          end
          lualine.setup(lualine_opts)
        end,
      })
    end,
    opts = function()
      local util = require("cyberdream.util")
      return {
        transparent = vim.g.user_transparent_background,
        italic_comments = true,
        borderless_telescope = {
          border = not borderless_telescope,
          style = "flat", -- nvchad
        },
        theme = {
          -- ~/.local/share/nvim/lazy/cyberdream.nvim/lua/cyberdream/colors.lua
          overrides = function(c)
            local illuminate = util.blend(c.bgHighlight, c.fg, 0.875)
            return {
              IlluminatedWordRead = { bg = illuminate },
              IlluminatedWordWrite = { bg = illuminate, underline = true },
              LspReferenceRead = { link = "IlluminatedWordRead" },
              LspReferenceWrite = { link = "IlluminatedWordWrite" },
              -- CmpGhostText = { bg = c.bg, fg = util.blend(c.grey, c.fg, 0.85) },
              DiagnosticUnnecessary = { fg = util.blend(c.grey, c.fg, 0.7) },
            }
          end,
        },
      }
    end,
  },

  -- custom illuminate highlight for all colorschemes which don't customize it
  {
    "RRethy/vim-illuminate",
    optional = true,
    opts = function()
      local function set_hl()
        local hl = vim.api.nvim_get_hl(0, { name = "IlluminatedWordWrite", link = false, create = false })
        if not (hl.bg and hl.underline) then
          -- local bg = Snacks.util.color("Normal", "bg")
          local visual = Snacks.util.color("Visual", "bg")
          local comment = Snacks.util.color("Comment")

          local illuminate = U.color.lighten(visual, 0.925)
          -- add `default = true` to avoid overriding colorscheme's highlight group
          vim.api.nvim_set_hl(0, "IlluminatedWordText", { bg = U.color.darken(visual, 0.9) })
          vim.api.nvim_set_hl(0, "IlluminatedWordRead", { bg = illuminate })
          vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = illuminate, underline = true })

          -- compensate for invisible text caused by custom illuminate highlight
          -- -- not necessary after disabling vim-illuminate in insert mode
          -- vim.api.nvim_set_hl(0, "CmpGhostText", { bg = bg, fg = U.color.lighten(comment, 0.85) })
          -- vim.api.nvim_set_hl(0, "BlinkCmpGhostText", { link = "CmpGhostText" })
          vim.api.nvim_set_hl(
            0,
            "DiagnosticUnnecessary",
            { fg = U.color.lighten(Snacks.util.color("DiagnosticUnnecessary") or comment, 0.7) }
          )
        end
      end
      set_hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      opts = opts or {}
      opts.colorscheme = random_colorscheme()

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymaps",
        once = true,
        callback = function()
          vim.keymap.set("n", "<leader>ur", function()
            local random = random_colorscheme()
            if random then
              vim.cmd.colorscheme(random)
              LazyVim.info(random, { title = "Random ColorScheme" })
            end
          end, { desc = "Random ColorScheme" })
        end,
      })
    end,
  },

  {
    "folke/snacks.nvim",
    optional = true,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          colorschemes = {
            transform = function(item)
              if vim.list_contains(ignored_colorschemes, item.text) then
                return false
              end
            end,
          },
        },
      },
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
              colors = vim.deepcopy(colorschemes),
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
