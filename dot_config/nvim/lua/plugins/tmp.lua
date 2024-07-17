-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/tmp.lua
return {
  {
    "2kabhishek/nerdy.nvim",
    cmd = "Nerdy",
    keys = {
      { "<leader>ci", "<cmd>Nerdy<cr>", desc = "Pick Icon" },
    },
  },
  {
    "fei6409/log-highlight.nvim",
    event = "BufRead *.log",
    opts = {},
  },
  {
    "echasnovski/mini.align",
    vscode = true,
    opts = {},
    keys = {
      { "ga", mode = { "n", "v" }, desc = "Align" },
      { "gA", mode = { "n", "v" }, desc = "Align with Preview" },
    },
  },

  {
    "OXY2DEV/markview.nvim",
    enabled = true,
    opts = {
      checkboxes = { enable = false },
      links = {
        inline_links = {
          hl = "@markup.link.label.markown_inline",
          -- icon = " ",
          icon = "󰌷 ",
          icon_hl = "@markup.link",
        },
        images = {
          hl = "@markup.link.label.markown_inline",
          -- icon = " ",
          icon = "󰥶 ",
          icon_hl = "@markup.link",
        },
      },
      code_blocks = {
        style = "language",
        hl = "CodeBlock",
        pad_amount = 0,
      },
      list_items = {
        shift_width = 2,
        marker_minus = {
          -- text = "●",
          text = "",
          hl = "@markup.list.markdown",
        },
        marker_plus = {
          -- text = "●",
          text = "",
          hl = "@markup.list.markdown",
        },
        marker_star = {
          -- text = "●",
          text = "",
          hl = "@markup.list.markdown",
        },
        marker_dot = {},
      },
      inline_codes = { enable = false },
      headings = {
        heading_1 = { style = "simple", hl = "Headline1" },
        heading_2 = { style = "simple", hl = "Headline2" },
        heading_3 = { style = "simple", hl = "Headline3" },
        heading_4 = { style = "simple", hl = "Headline4" },
        heading_5 = { style = "simple", hl = "Headline5" },
        heading_6 = { style = "simple", hl = "Headline6" },
      },
      -- https://github.com/OXY2DEV/markview.nvim/issues/25#issuecomment-2224586784
      options = {
        on_enable = {
          conceallevel = 2,
          concealcursor = "",
        },
        on_disable = {
          conceallevel = 0,
          concealcursor = "",
        },
      },
    },

    ft = { "markdown", "norg", "rmd", "org" },
    specs = {
      "lukas-reineke/headlines.nvim",
      enabled = false,
    },
  },

  -- https://github.com/nvim-orgmode/orgmode/blob/master/DOCS.md#mappings
  -- https://github.com/ales-tsurko/neovim-config/blob/f6d6e86c8d1b545d4de110513e2758edb9a31d6b/lua/extensions/orgmode.lua
  -- https://github.com/milanglacier/nvim/blob/8a7de805a0a79aeb0b2498a804bd00d9fe254d21/lua/plugins/org.lua
  -- https://github.com/vkrit/dotfiles/blob/b090344511c5f5ea02e6a387ce69851be13a5526/dot_config/lvim/config.lua#L94
  -- https://github.com/lukas-reineke/dotfiles/blob/3a1afd9bad999cc2cdde98851c2a5066f60fc193/vim/lua/plugins/org.lua
  -- https://github.com/tobymelin/configs/blob/d65a22add5f5744272c6c46549f21a36f109e80f/nvim/lua/plugins/orgmode.lua#L4
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    keys = {
      { "<leader>o", "", desc = "+orgmode" },
    },
    opts = {
      org_agenda_files = "~/org/**/*",
      org_default_notes_file = "~/org/refile.org",
      mappings = {
        -- disable_all = true,

        -- global = {
        --   org_agenda = "gA",
        --   org_capture = "gC",
        -- },

        -- prefix = "<Leader>o",
      },
    },
  },

  -- {
  --   "Bekaboo/dropbar.nvim",
  --   dependencies = { "nvim-telescope/telescope-fzf-native.nvim", optional = true },
  -- },
}
