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
}
