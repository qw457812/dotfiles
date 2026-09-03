---@type LazySpec
return {
  {
    "nvim-mini/mini.test",
    optional = true,
    -- stylua: ignore
    keys = {
      { "<leader>tma", function() require("mini.test").run() end, desc = "Run All (MiniTest)" },
      { "<leader>tmf", function() require("mini.test").run_file() end, desc = "Run File (MiniTest)" },
      { "<leader>tmr", function() require("mini.test").run_at_location() end, desc = "Run Nearest (MiniTest)" },
    },
    opts = {
      collect = {
        find_files = function()
          return vim.fn.globpath(U.path.CONFIG .. "/tests", "**/test_*.lua", true, true)
        end,
      },
    },
    specs = {
      {
        "folke/which-key.nvim",
        opts = {
          spec = {
            { "<leader>tm", group = "MiniTest", icon = { icon = " ", color = "red" } },
          },
        },
      },
    },
  },

  {
    "folke/sidekick.nvim",
    optional = true,
    ---@module "sidekick"
    ---@type sidekick.Config
    opts = {
      cli = {
        ---@type sidekick.cli.Mux
        mux = {
          ---@diagnostic disable-next-line: assign-type-mismatch
          -- backend = "herdr",
        },
      },
    },
  },
}
