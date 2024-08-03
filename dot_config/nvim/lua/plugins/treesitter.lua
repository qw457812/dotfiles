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
}
