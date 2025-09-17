---@type LazySpec
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "mermaid", "groovy" } },
  },

  {
    "OXY2DEV/helpview.nvim",
    ft = "help",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      opts = { ensure_installed = { "vimdoc" } },
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
