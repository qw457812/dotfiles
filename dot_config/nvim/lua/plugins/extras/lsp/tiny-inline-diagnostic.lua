return {
  -- https://github.com/search?q=repo%3Aaimuzov%2FLazyVimx%20tiny-inline-diagnostic.nvim&type=code
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    commit = "e747d78db6f9a2aa8a86ee3120708887197b7352", -- TODO: python
    event = "VeryLazy",
    dependencies = {
      "neovim/nvim-lspconfig",
      -- for `vim.diagnostic.config({ virtual_text = false })`
      -- see: https://github.com/LazyVim/LazyVim/blob/13a4a84e3485a36e64055365665a45dc82b6bf71/lua/lazyvim/plugins/lsp/init.lua#L183
      opts = { diagnostics = { virtual_text = false } },
    },
    opts = {
      signs = {
        left = " ",
        right = " ",
        arrow = "  ",
        up_arrow = "  ",
      },
      -- options = { virt_texts = { priority = 5000 } },
    },
  },
}
