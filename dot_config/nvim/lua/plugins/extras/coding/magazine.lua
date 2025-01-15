return {
  -- nvim-cmp fork
  -- make sure to use `nvim-cmp` instead of `hrsh7th/nvim-cmp` in ~/.config/nvim/lua/plugins/*
  -- alternative:
  -- * https://github.com/LazyVim/LazyVim/pull/4804#issuecomment-2543500773
  -- * https://github.com/AstroNvim/astrocommunity/blob/6426600f2964f350377cc3627b868fc10286b286/lua/astrocommunity/completion/magazine-nvim/init.lua
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
