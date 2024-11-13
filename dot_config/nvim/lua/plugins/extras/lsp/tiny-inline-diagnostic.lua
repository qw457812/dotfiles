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
        right = " ",
        arrow = "  ",
        up_arrow = "  ",
      },
      -- options = { virt_texts = { priority = 5000 } },
    },
    config = function(_, opts)
      require("tiny-inline-diagnostic").setup(opts)

      -- fix: respect diagnostic_virtual_text toggle, sometimes automatically switches back to true
      -- see: https://github.com/rachartier/tiny-inline-diagnostic.nvim/blob/86050f39a62de48734f1a2876d70d179b75deb7c/lua/tiny-inline-diagnostic/diagnostic.lua#L310
      vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "[vV\x16is]*:*",
        callback = function()
          if U.toggle.has_diagnostic_virtual_text == false then
            vim.defer_fn(function()
              U.toggle.diagnostic_virtual_text:set(false)
            end, 0)
          end
        end,
      })
    end,
  },
}
