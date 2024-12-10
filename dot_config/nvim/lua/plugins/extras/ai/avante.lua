-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/completion/avante-nvim/init.lua
return {
  {
    "yetone/avante.nvim",
    build = "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "MunifTanjim/nui.nvim",
      "zbirenbaum/copilot.lua", -- for `provider = "copilot"`
      { "nvim-cmp", optional = true },
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
        ft = U.markdown.render_markdown_ft("Avante"),
      },
    },
    -- https://github.com/yetone/avante.nvim/wiki#keymaps-and-api-i-guess
    -- ~/.local/share/nvim/lazy/avante.nvim/lua/avante/init.lua
    -- TODO: https://github.com/yetone/avante.nvim/wiki/Recipe-and-Tricks
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
    ---@type avante.Config
    opts = {
      mappings = {
        toggle = {
          debug = "<leader>aD",
        },
        sidebar = {
          -- disable since <tab> is mapped to <C-w>w
          switch_windows = "<A-Down>",
          reverse_switch_windows = "<A-Up>",
        },
      },
      behaviour = {
        -- auto_suggestions = true, -- experimental
        auto_apply_diff_after_generation = true,
      },
      provider = "copilot-claude", -- only recommend using claude
      auto_suggestions_provider = "copilot-claude", -- high-frequency, can be expensive if enabled
      -- copilot = {
      --   model = "claude-3.5-sonnet",
      -- },
      -- https://github.com/yetone/avante.nvim/wiki/Custom-providers
      vendors = {
        -- be able to switch between copilot (gpt-4o) and copilot-claude
        ---@type AvanteSupportedProvider
        ["copilot-claude"] = {
          __inherited_from = "copilot",
          -- https://github.com/CopilotC-Nvim/CopilotChat.nvim#models
          model = "claude-3.5-sonnet",
        },
        -- https://github.com/yetone/avante.nvim/pull/159
        ---@type AvanteSupportedProvider
        groq = {
          __inherited_from = "openai",
          api_key_name = "GROQ_API_KEY",
          endpoint = "https://api.groq.com/openai/v1/",
          -- https://console.groq.com/docs/models
          -- curl -X GET "https://api.groq.com/openai/v1/models" -H "Authorization: Bearer $GROQ_API_KEY" -H "Content-Type: application/json" | jq .
          model = "llama-3.1-70b-versatile",
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
