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
  -- {
  --   "echasnovski/mini.align",
  --   opts = {},
  --   keys = {
  --     { "ga", mode = { "n", "v" } },
  --     { "gA", mode = { "n", "v" } },
  --   },
  -- },

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
  --   "tris203/precognition.nvim",
  --   event = "VeryLazy",
  --   opts = {
  --     startVisible = true,
  --     showBlankVirtLine = false,
  --     highlightColor = { link = "Comment" },
  --     hints = {
  --       Caret = { text = "^", prio = 0 },
  --       Dollar = { text = "$", prio = 0 },
  --       MatchingPair = { text = "%", prio = 0 },
  --       Zero = { text = "0", prio = 0 },
  --       w = { text = "w", prio = 10 },
  --       b = { text = "b", prio = 9 },
  --       e = { text = "e", prio = 8 },
  --       W = { text = "W", prio = 7 },
  --       B = { text = "B", prio = 6 },
  --       E = { text = "E", prio = 5 },
  --     },
  --     gutterHints = {
  --       G = { text = "G", prio = 0 },
  --       gg = { text = "gg", prio = 0 },
  --       PrevParagraph = { text = "{", prio = 8 },
  --       NextParagraph = { text = "}", prio = 8 },
  --     },
  --   },
  -- },
}
