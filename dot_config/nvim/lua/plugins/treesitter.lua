---@type LazySpec
return {
  {
    "nvim-treesitter/nvim-treesitter",
    keys = {
      { "<c-space>", false },
      { "<bs>", false, mode = "x" },
      { "K", desc = "Increment Selection", mode = "x" },
      { "J", desc = "Decrement Selection", mode = "x" },
    },
    opts = function(_, opts)
      -- https://github.com/nvim-treesitter/nvim-treesitter#supported-languages
      vim.list_extend(opts.ensure_installed, {
        "mermaid",
        "groovy",
      })

      opts.incremental_selection = vim.tbl_deep_extend("force", opts.incremental_selection or {}, {
        keymaps = {
          init_selection = false,
          node_incremental = "K",
          node_decremental = "J",
        },
      })
    end,
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "J", desc = "Decrement Selection", mode = "x" },
        { "K", desc = "Increment Selection", mode = "x" },
      },
    },
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
      { "<leader>uH", "<cmd>Helpview Toggle<cr>", desc = "Helpview" },
    },
    opts = {
      preview = {
        icon_provider = "mini",
      },
    },
    config = function(_, opts)
      require("helpview").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("helpview_fix_lazy", { clear = true }),
        pattern = "help",
        once = true,
        callback = function()
          vim.cmd("Helpview attach")
        end,
      })
    end,
  },

  {
    "fei6409/log-highlight.nvim",
    event = "BufRead *.log",
    ft = "log",
    opts = {},
  },
}
