local formatter = "shfmt" -- beautysh

return {
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { formatter } },
  },

  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.zsh = { formatter }
    end,
  },
}
