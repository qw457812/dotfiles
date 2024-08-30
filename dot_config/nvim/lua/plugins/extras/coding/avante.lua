-- :=require("render-markdown").default_config.file_types
local render_markdown_ft = LazyVim.opts("markdown.nvim").file_types or { "markdown" }
table.insert(render_markdown_ft, "Avante")

return {
  {
    "yetone/avante.nvim",
    dependencies = {
      "stevearc/dressing.nvim",
      "MunifTanjim/nui.nvim",
      "zbirenbaum/copilot.lua", -- for providers='copilot'
      { "echasnovski/mini.icons", optional = true },
      -- {
      --   -- support for image pasting
      --   "HakonHarnes/img-clip.nvim",
      --   event = "VeryLazy",
      --   opts = {
      --     default = {
      --       embed_image_as_base64 = false,
      --       prompt_for_file_name = false,
      --       drag_and_drop = {
      --         insert_mode = true,
      --       },
      --       -- required for Windows users
      --       use_absolute_path = true,
      --     },
      --   },
      -- },
      {
        "MeanderingProgrammer/markdown.nvim",
        optional = true,
        opts = {
          file_types = render_markdown_ft,
        },
        ft = render_markdown_ft,
      },
    },
    keys = {
      {
        "<leader>aa",
        function()
          require("avante.api").ask()
        end,
        desc = "Ask (Avante)",
        mode = { "n", "v" },
      },
      {
        "<leader>ar",
        function()
          require("avante.api").refresh()
        end,
        desc = "Refresh (Avante)",
      },
      {
        "<leader>ae",
        function()
          require("avante.api").edit()
        end,
        desc = "Edit (Avante)",
        mode = "v",
      },
    },
    opts = {
      provider = "copilot", -- claude(recommend), openai, azure, gemini, cohere, copilot
    },
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    optional = true,
    keys = {
      { "<leader>aa", mode = { "n", "v" }, false },
      {
        "<leader>ac",
        function()
          return require("CopilotChat").toggle()
        end,
        desc = "Toggle (CopilotChat)",
        mode = { "n", "v" },
      },
    },
  },
}
