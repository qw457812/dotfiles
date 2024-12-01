if vim.fn.executable("exercism") == 0 then
  return {}
end

local function exercism_workspace()
  local res = vim.system({ "exercism", "workspace" }, { text = true }):wait()
  return res.code == 0 and res.stdout:gsub("[\r\n]+$", "") or nil
end

return {
  {
    "2kabhishek/exercism.nvim",
    dependencies = {
      "2kabhishek/utils.nvim",
      { "stevearc/dressing.nvim", optional = true },
      -- "2kabhishek/termim.nvim", -- optional, better UI for ExercismTest
    },
    cmd = { "ExercismLanguages", "ExercismList", "ExercismSubmit", "ExercismTest" },
    keys = {
      { "<leader>Ea", "<cmd>ExercismLanguages<cr>", desc = "Exercism Languages" },
      { "<leader>El", "<cmd>ExercismList<cr>", desc = "Exercism List" },
      { "<leader>Es", "<cmd>ExercismSubmit<cr>", desc = "Exercism Submit" },
      { "<leader>Et", "<cmd>ExercismTest<cr>", desc = "Exercism Test" },
    },
    opts = {
      add_default_keybindings = false,
      exercism_workspace = exercism_workspace(),
      default_language = "python",
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>E", group = "exercism", icon = { icon = "󰘦 ", color = "purple" } },
      },
    },
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    keys = { { "<leader>E", false } },
  },
}
