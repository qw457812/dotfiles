return {
  -- https://github.com/search?q=repo%3Aaimuzov%2FLazyVimx%20tiny-inline-diagnostic.nvim&type=code
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    -- priority = 1000,
    lazy = false,
    -- event = "VeryLazy", -- LspAttach
    dependencies = {
      "neovim/nvim-lspconfig",
      -- for `vim.diagnostic.config({ virtual_text = false })`
      -- see: https://github.com/LazyVim/LazyVim/blob/13a4a84e3485a36e64055365665a45dc82b6bf71/lua/lazyvim/plugins/lsp/init.lua#L183
      opts = { diagnostics = { virtual_text = false } },
    },
    opts = {
      signs = {
        left = " ",
        right = "",
        arrow = "  ",
        up_arrow = "  ",
      },
      options = {
        virt_texts = { priority = 5000 }, -- set higher than symbol-usage.nvim
        use_icons_from_diagnostic = true,
        -- multilines = true, -- not just current line
        -- show_source = true,
      },
    },
  },
}
