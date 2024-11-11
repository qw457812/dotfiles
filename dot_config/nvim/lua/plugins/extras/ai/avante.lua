return {
  {
    "yetone/avante.nvim",
    build = "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
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
        "MeanderingProgrammer/render-markdown.nvim",
        optional = true,
        ft = (function()
          local plugin = LazyVim.get_plugin("render-markdown.nvim")
          -- :=require("render-markdown").default_config.file_types
          -- local ft = plugin and require("lazy.core.plugin").values(plugin, "ft", false) or { "markdown" }
          local ft = plugin and plugin.ft or { "markdown" }
          ft = type(ft) == "table" and ft or { ft }
          ft = vim.deepcopy(ft)
          table.insert(ft, "Avante")
          return ft
        end)(),
      },
    },
    -- init = function()
    --   require("avante_lib").load() -- this break lazy loading
    -- end,
    -- https://github.com/yetone/avante.nvim/wiki#keymaps-and-api-i-guess
    -- ~/.local/share/nvim/lazy/avante.nvim/lua/avante/init.lua
    keys = function(_, keys)
      local opts_mappings = LazyVim.opts("avante.nvim").mappings or {}
      -- stylua: ignore
      local mappings = {
        { opts_mappings.ask or "<leader>aa", mode = { "n", "v" }, function() require("avante.api").ask() end, desc = "Ask (Avante)" },
        { opts_mappings.edit or "<leader>ae", mode = "v", function() require("avante.api").edit() end, desc = "Edit (Avante)" },
        { opts_mappings.refresh or "<leader>ar", function() require("avante.api").refresh() end, desc = "Refresh (Avante)" },
        {
          "<leader>aP",
          function()
            -- https://github.com/yetone/avante.nvim/blob/962dd0a759d9cba7214dbc954780c5ada5799449/lua/avante/init.lua#L47
            vim.ui.select(require("avante.config").providers, { prompt = "Select Avante Provider:" }, function(choice)
              if choice then
                require("avante.api").switch_provider(choice)
              end
            end)
          end,
          desc = "Switch Provider (Avante)",
        },
      }
      vim.list_extend(keys, mappings)
    end,
    opts = {
      mappings = {
        toggle = {
          debug = "<leader>aD",
        },
      },
      provider = "copilot", -- claude(recommend), openai, azure, gemini, cohere, copilot, groq(custom)
      auto_suggestions_provider = "copilot", -- high-frequency
      -- behaviour = {
      --   auto_suggestions = true, -- experimental
      -- },
      -- https://github.com/yetone/avante.nvim/wiki#custom-providers
      -- https://github.com/yetone/avante.nvim/pull/159
      vendors = {
        ---@type AvanteProvider
        groq = {
          endpoint = "https://api.groq.com/openai/v1/chat/completions",
          model = "llama-3.2-90b-text-preview",
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
                messages = require("avante.providers.openai").parse_messages(code_opts), -- you can make your own message, but this is very advanced
                temperature = 0,
                max_tokens = 8000,
                stream = true, -- this will be set by default.
              },
            }
          end,
          parse_response_data = function(data_stream, event_state, opts)
            require("avante.providers").openai.parse_response(data_stream, event_state, opts)
          end,
        },
      },
      hints = { enabled = false },
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
}
