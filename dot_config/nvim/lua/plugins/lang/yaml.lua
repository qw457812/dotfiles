return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      vim.filetype.add({
        pattern = {
          [".*/.github/workflows/.*%.yml"] = "yaml.ghaction",
          [".*/.github/workflows/.*%.yaml"] = "yaml.ghaction",
        },
      })
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "actionlint" } },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        ["yaml.ghaction"] = { "actionlint" },
      },
    },
  },
}
