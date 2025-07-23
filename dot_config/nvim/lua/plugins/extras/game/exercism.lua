if vim.fn.executable("exercism") == 0 then
  return {}
end

local function exercism_workspace()
  local res = vim.system({ "exercism", "workspace" }, { text = true }):wait()
  return res.code == 0 and res.stdout:gsub("\n+$", "") or nil
end

return {
  {
    "2kabhishek/exercism.nvim",
    dependencies = {
      "2kabhishek/utils.nvim",
      -- "2kabhishek/termim.nvim", -- optional, better UI for `Exercism test`
    },
    cmd = "Exercism",
    keys = {
      { "<leader>Ea", "<cmd>Exercism languages<cr>", desc = "Languages" },
      { "<leader>El", "<cmd>Exercism list<cr>", desc = "List" },
      { "<leader>Es", "<cmd>Exercism submit<cr>", desc = "Submit" },
      { "<leader>Et", "<cmd>Exercism test<cr>", desc = "Test" },
    },
    opts = {
      use_new_command = true,
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
  {
    "folke/snacks.nvim",
    keys = function(_, keys)
      if LazyVim.has_extra("editor.snacks_explorer") then
        table.insert(keys, { "<leader>E", false })
      end
    end,
  },
}
