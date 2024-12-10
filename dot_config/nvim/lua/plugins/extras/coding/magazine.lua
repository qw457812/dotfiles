return {
  -- nvim-cmp fork
  -- make sure to use `nvim-cmp` instead of `hrsh7th/nvim-cmp` in ~/.config/nvim/lua/plugins/*
  {
    "iguanacucumber/magazine.nvim",
    name = "nvim-cmp",
    optional = true,
    dependencies = {
      { "iguanacucumber/mag-nvim-lsp", name = "cmp-nvim-lsp", opts = {} },
      { "iguanacucumber/mag-nvim-lua", name = "cmp-nvim-lua" },
      { "iguanacucumber/mag-buffer", name = "cmp-buffer" },
      { "iguanacucumber/mag-cmdline", name = "cmp-cmdline" },
      { "https://codeberg.org/FelipeLema/cmp-async-path", name = "cmp-path" },
    },
  },
}
