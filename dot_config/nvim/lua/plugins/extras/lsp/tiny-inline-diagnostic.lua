return {
  -- https://github.com/search?q=repo%3Aaimuzov%2FLazyVimx%20tiny-inline-diagnostic.nvim&type=code
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    -- priority = 1000,
    lazy = false,
    -- event = "VeryLazy", -- LspAttach
    opts = {
      signs = {
        left = " ",
        right = " ",
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
