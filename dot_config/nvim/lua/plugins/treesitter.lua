return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- https://github.com/nvim-treesitter/nvim-treesitter#supported-languages
      -- :=vim.list_contains(LazyVim.opts("nvim-treesitter").ensure_installed, "org")
      vim.list_extend(opts.ensure_installed, {
        -- "org",
        "mermaid",
        "groovy",
      })
    end,
  },

  {
    "OXY2DEV/helpview.nvim",
    ft = "help",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
        table.insert(opts.ensure_installed, "vimdoc")
      end,
    },
    keys = {
      { "<leader>uH", "<cmd>Helpview toggleAll<cr>", desc = "Helpview" },
    },
  },

  -- https://github.com/folke/dot/blob/39602b7edc7222213bce762080d8f46352167434/nvim/lua/plugins/tmp.lua#L112
  {
    "fei6409/log-highlight.nvim",
    event = "BufRead *.log",
    opts = {},
  },
}
