return {
  -- zsh
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.zsh = { "shfmt" }
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "shfmt" } },
  },

  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "karabiner.edn",
        callback = function(event)
          vim.b[event.buf].autoformat = false
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      vim.treesitter.language.register("vim", "vifm")
    end,
  },
}
