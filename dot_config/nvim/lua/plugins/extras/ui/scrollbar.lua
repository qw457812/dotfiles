return {
  {
    "petertriho/nvim-scrollbar",
    event = "VeryLazy",
    opts = function()
      local config = require("scrollbar.config").get()
      return {
        excluded_filetypes = vim.list_extend(vim.deepcopy(config.excluded_filetypes), {
          "dashboard",
          "neo-tree",
          "neo-tree-popup",
          "minifiles",
          "edgy",
          "trouble",
          "notify",
          "rip-substitute",
          "qf",
          "lazy",
          "mason",
        }),
      }
    end,
  },
}
