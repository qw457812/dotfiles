-- :=require("render-markdown").default_config.file_types
local render_markdown_ft = LazyVim.opts("markdown.nvim").file_types or { "markdown" }
table.insert(render_markdown_ft, "Avante")

return {
  {
    "yetone/avante.nvim",
    dependencies = {
      "stevearc/dressing.nvim",
      "MunifTanjim/nui.nvim",
      "zbirenbaum/copilot.lua", -- for `provider = "copilot"`
      { "echasnovski/mini.icons", optional = true },
      {
        "HakonHarnes/img-clip.nvim", -- support for image pasting
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            use_absolute_path = true, -- required for Windows users
          },
        },
      },
      {
        "MeanderingProgrammer/markdown.nvim",
        optional = true,
        opts = {
          file_types = render_markdown_ft,
        },
        ft = render_markdown_ft,
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>aa", mode = { "n", "v" }, function() require("avante.api").ask() end, desc = "Ask (Avante)" },
      { "<leader>ar", function() require("avante.api").refresh() end, desc = "Refresh (Avante)" },
      { "<leader>ae", mode = "v", function() require("avante.api").edit() end, desc = "Edit (Avante)" },
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
      -- stylua: ignore
      { "<leader>ac", mode = { "n", "v" }, function() return require("CopilotChat").toggle() end, desc = "Toggle (CopilotChat)" },
    },
  },

  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      opts.right = opts.right or {}
      -- stylua: ignore
      vim.list_extend(opts.right, {
        { ft = "Avante",      title = "Avante",       size = { width = 50, height = 0.775 } },
        { ft = "AvanteInput", title = "Avante Input", size = { width = 50, height = 0.225 } },
      })
    end,
  },
}
