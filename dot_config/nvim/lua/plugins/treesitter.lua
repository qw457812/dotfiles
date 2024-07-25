return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- :=LazyVim.opts("nvim-treesitter").ensure_installed
      vim.list_extend(opts.ensure_installed, {
        -- "org",
        "mermaid",
      })
    end,
  },
}
