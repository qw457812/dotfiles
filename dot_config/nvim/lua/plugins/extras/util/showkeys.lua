---@type LazySpec
return {
  {
    "nvchad/showkeys",
    event = "VeryLazy",
    keys = {
      { "<leader>uk", "<cmd>ShowkeysToggle<cr>", desc = "Show keys" },
    },
    opts = {
      -- timeout = 1,
      maxkeys = 5,
      show_count = true,
      position = "top-right",
    },
    config = function(_, opts)
      local showkeys = require("showkeys")
      showkeys.setup(opts)
      showkeys.open()
    end,
  },
}
