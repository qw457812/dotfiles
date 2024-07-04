return {
  -- https://github.com/folke/dot/blob/master/nvim/lua/plugins/ui.lua
  -- "folke/twilight.nvim",
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    opts = {
      plugins = {
        gitsigns = true,
        tmux = true,
        kitty = { enabled = false, font = "+2" },
      },
    },
    keys = { { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen Mode" } },
  },

  {
    "tzachar/highlight-undo.nvim",
    event = "VeryLazy",
    vscode = true,
    opts = function()
      vim.api.nvim_set_hl(0, "HighlightUndo", { default = true, link = "IncSearch" })
      vim.api.nvim_set_hl(0, "HighlightRedo", { default = true, link = "HighlightUndo" })
      return {
        --[[add custom config here]]
      }
    end,

    -- alternative 1:
    -- -- opts = {},
    -- -- config = function(_, opts)
    -- --   vim.api.nvim_set_hl(0, "HighlightUndo", { default = true, link = "IncSearch" })
    -- --   vim.api.nvim_set_hl(0, "HighlightRedo", { default = true, link = "HighlightUndo" })
    -- --   require("highlight-undo").setup(opts) -- after `vim.api.nvim_set_hl`
    -- -- end,
    --
    -- alternative 2:
    -- -- opts = {},
    -- -- init = function()
    -- --   vim.api.nvim_set_hl(0, "HighlightUndo", { default = true, link = "IncSearch" })
    -- --   vim.api.nvim_set_hl(0, "HighlightRedo", { default = true, link = "HighlightUndo" })
    -- -- end,
  },

  {
    "shortcuts/no-neck-pain.nvim",
    opts = {},
    keys = {
      { "<leader>uN", "<cmd>NoNeckPain<cr>", desc = "No Neck Pain" },
    },
  },

  -- :h bufferline-configuration
  {
    "akinsho/bufferline.nvim",
    keys = {
      { "<Up>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<Down>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "<leader>bH", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto First Buffer" },
      { "<leader>b1", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto Buffer 1" },
      { "<leader>b2", "<cmd>BufferLineGoToBuffer 2<cr>", desc = "Goto Buffer 2" },
      { "<leader>b3", "<cmd>BufferLineGoToBuffer 3<cr>", desc = "Goto Buffer 3" },
      { "<leader>b4", "<cmd>BufferLineGoToBuffer 4<cr>", desc = "Goto Buffer 4" },
      { "<leader>b5", "<cmd>BufferLineGoToBuffer 5<cr>", desc = "Goto Buffer 5" },
      { "<leader>b6", "<cmd>BufferLineGoToBuffer 6<cr>", desc = "Goto Buffer 6" },
      { "<leader>b7", "<cmd>BufferLineGoToBuffer 7<cr>", desc = "Goto Buffer 7" },
      { "<leader>b8", "<cmd>BufferLineGoToBuffer 8<cr>", desc = "Goto Buffer 8" },
      { "<leader>b9", "<cmd>BufferLineGoToBuffer 9<cr>", desc = "Goto Buffer 9" },
      { "<leader>bL", "<cmd>BufferLineGoToBuffer -1<cr>", desc = "Goto Last Buffer" },
    },
    opts = {
      options = {
        separator_style = "slope",
      },
    },
  },
}
