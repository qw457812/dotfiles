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
        cmd = "PasteImage",
        keys = {
          {
            '"i',
            function()
              return vim.bo.filetype == "AvanteInput" and require("avante.clipboard").paste_image()
                or require("img-clip").paste_image()
            end,
            desc = "Paste Image (img-clip)",
          },
        },
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
      -- provider = "groq",
      -- https://github.com/yetone/avante.nvim/wiki#custom-providers
      vendors = {
        ---@type AvanteProvider
        groq = {
          endpoint = "https://api.groq.com/openai/v1/chat/completions",
          model = "llama-3.1-70b-versatile",
          api_key_name = "GROQ_API_KEY",
          parse_curl_args = function(opts, code_opts)
            return {
              url = opts.endpoint,
              headers = {
                ["Accept"] = "application/json",
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. os.getenv(opts.api_key_name),
              },
              body = {
                model = opts.model,
                messages = { -- you can make your own message, but this is very advanced
                  { role = "system", content = code_opts.system_prompt },
                  { role = "user", content = require("avante.providers.openai").get_user_message(code_opts) },
                },
                temperature = 0,
                max_tokens = 4096,
                stream = true, -- this will be set by default.
              },
            }
          end,
          parse_response_data = function(data_stream, event_state, opts)
            require("avante.providers").openai.parse_response(data_stream, event_state, opts)
          end,
        },
      },
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

  -- -- not working well with `<leader>aa`
  -- {
  --   "folke/edgy.nvim",
  --   optional = true,
  --   opts = function(_, opts)
  --     opts.right = opts.right or {}
  --     -- stylua: ignore
  --     vim.list_extend(opts.right, {
  --       { ft = "Avante",      title = "Avante",       size = { width = 50, height = 0.775 } },
  --       { ft = "AvanteInput", title = "Avante Input", size = { width = 50, height = 0.225 } },
  --     })
  --   end,
  -- },
}
