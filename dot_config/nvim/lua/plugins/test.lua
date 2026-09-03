---@type LazySpec
return {
  {
    "nvim-mini/mini.test",
    lazy = true,
    specs = {
      {
        "folke/lazydev.nvim",
        opts = function(_, opts)
          opts.library = opts.library or {}
          table.insert(opts.library, { path = "mini.test", words = { "MiniTest" } })
        end,
      },
    },
  },
}
