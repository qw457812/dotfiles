-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/tmp.lua
return {
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        separator_style = "slope",
      },
    },
  },
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
      { "<leader>O", "", desc = "+orgmode" },
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

        -- TODO temp, default is <leader>o
        prefix = "<Leader>O",
      },
    },
  },
}
