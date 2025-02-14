return {
  {
    "nvchad/showkeys",
    cmd = "ShowkeysToggle",
    keys = {
      { "<leader>uk", "<cmd>ShowkeysToggle<cr>", desc = "Show keys" },
    },
    opts = {
      -- timeout = 1,
      maxkeys = 5,
      show_count = true,
      position = "top-right",
    },
  },
}
