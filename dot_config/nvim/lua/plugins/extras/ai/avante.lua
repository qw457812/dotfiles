local mapping_disabled_prefix = "<leader>av<localleader>"

-- https://github.com/yetone/avante.nvim/wiki/Recipe-and-Tricks
---@type table<string, string|fun():string>
local prompt = {
  grammar_correction = "Correct the text to standard English, but keep any code blocks inside intact.",
  code_readability_analysis = [[
  You must identify any readability issues in the code snippet.
  Some readability issues to consider:
  - Unclear naming
  - Unclear purpose
  - Redundant or obvious comments
  - Lack of comments
  - Long or complex one liners
  - Too much nesting
  - Long variable names
  - Inconsistent naming and code style.
  - Code repetition
  You may identify additional problems. The user submits a small section of code from a larger file.
  Only list lines with readability issues, in the format <line_num>|<issue and proposed solution>
  If there's no issues with code respond with only: <OK>
]],
  optimize_code = "Optimize the following code",
  summarize = "Summarize the following text",
  translate = "Translate this into Chinese, but keep any code blocks inside intact",
  explain_code = "Explain the following code",
  complete_code = function()
    return "Complete the following codes written in " .. vim.bo.filetype
  end,
  add_docstring = "Add docstring to the following codes",
  fix_bugs = "Fix the bugs inside the following codes if any",
  add_tests = "Implement tests for the following code",
}

---@param question string|fun():string
---@return function
local function ask(question)
  return function()
    ---@cast question string
    question = vim.is_callable(question) and question() or question
    require("avante.api").ask({ question = question })
  end
end

-- prefill edit window with common scenarios to avoid repeating query and submit immediately
---@param question string|fun():string
---@return function
local function edit_submit(question)
  return function()
    ---@cast question string
    question = vim.is_callable(question) and question() or question
    require("avante.api").edit()
    vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, -1, false, { question })
    -- optionally set the cursor position to the end of the input
    vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { 1, #question + 1 })
    -- simulate ctrl+s keypress to submit
    vim.api.nvim_feedkeys(vim.keycode("<C-s>"), "m", false)
  end
end

local function switch_provider()
  -- https://github.com/yetone/avante.nvim/blob/962dd0a759d9cba7214dbc954780c5ada5799449/lua/avante/init.lua#L47
  vim.ui.select(require("avante.config").providers, { prompt = "Select Avante Provider:" }, function(choice)
    if choice then
      require("avante.api").switch_provider(choice)
    end
  end)
end

-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/completion/avante-nvim/init.lua
return {
  {
    "yetone/avante.nvim",
    lazy = false, -- see: https://github.com/yetone/avante.nvim/issues/561#issuecomment-2342550208
    build = "make",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        opts = {
          -- copied from: https://github.com/yetone/avante.nvim/pull/1181
          highlight = {
            disable = function(_, buf)
              if vim.bo[buf].filetype == "Avante" then
                local sidebar = require("avante").get()
                if sidebar and sidebar.is_generating then
                  return true
                end
              end
            end,
          },
        },
      },
      "stevearc/dressing.nvim",
      "MunifTanjim/nui.nvim",
      "zbirenbaum/copilot.lua", -- for `provider = "copilot"`
      -- {
      --   "HakonHarnes/img-clip.nvim", -- support for image pasting
      --   cmd = "PasteImage",
      --   keys = {
      --     {
      --       '"i',
      --       function()
      --         return vim.bo.filetype == "AvanteInput" and require("avante.clipboard").paste_image()
      --           or require("img-clip").paste_image()
      --       end,
      --       desc = "Paste Image (img-clip)",
      --     },
      --   },
      --   opts = {
      --     default = {
      --       embed_image_as_base64 = false,
      --       prompt_for_file_name = false,
      --       drag_and_drop = {
      --         insert_mode = true,
      --       },
      --       use_absolute_path = true, -- required for Windows users
      --     },
      --   },
      -- },
      {
        "MeanderingProgrammer/render-markdown.nvim",
        optional = true,
        ft = U.markdown.render_markdown_ft("Avante"),
      },
    },
    keys = function(_, keys)
      local opts_mappings = LazyVim.opts("avante.nvim").mappings or {}
      local mappings = {
        { mapping_disabled_prefix, "", desc = "+disabled" },
        {
          opts_mappings.ask or "<leader>aa",
          function()
            require("avante.api").ask()
            local sidebar = require("avante").get()
            if sidebar and sidebar:is_open() then
              sidebar:focus_input()
            end
          end,
          desc = "Ask (Avante)",
          mode = { "n", "v" },
        },
        -- stylua: ignore start
        { opts_mappings.edit or "<leader>ae", function() require("avante.api").edit() end, desc = "Edit (Avante)", mode = "v" },
        { opts_mappings.refresh or "<leader>ar", function() require("avante.api").refresh() end, desc = "Refresh (Avante)" },
        { opts_mappings.focus or "<leader>af", function() require("avante.api").focus() end, desc = "Focus (Avante)" },
        { "<leader>aP", switch_provider, desc = "Switch Provider (Avante)" },
        { "<leader>av", "", desc = "+avante", mode = { "n", "v" } },
        { "<leader>avg", ask(prompt.grammar_correction),         desc = "Grammar Correction (Ask)",        mode = { "n", "v" } },
        { "<leader>avG", edit_submit(prompt.grammar_correction), desc = "Grammar Correction (Edit)",       mode = "v" },
        { "<leader>avr", ask(prompt.code_readability_analysis),  desc = "Code Readability Analysis (Ask)", mode = { "n", "v" } },
        { "<leader>avo", ask(prompt.optimize_code),              desc = "Optimize Code (Ask)",             mode = { "n", "v" } },
        { "<leader>avO", edit_submit(prompt.optimize_code),      desc = "Optimize Code (Edit)",            mode = "v" },
        { "<leader>avs", ask(prompt.summarize),                  desc = "Summarize text (Ask)",            mode = { "n", "v" } },
        { "<leader>avt", ask(prompt.translate),                  desc = "Translate text (Ask)",            mode = { "n", "v" } },
        { "<leader>ave", ask(prompt.explain_code),               desc = "Explain Code (Ask)",              mode = { "n", "v" } },
        { "<leader>avc", ask(prompt.complete_code),              desc = "Complete Code (Ask)",             mode = { "n", "v" } },
        { "<leader>avC", edit_submit(prompt.complete_code),      desc = "Complete Code (Edit)",            mode = "v" },
        { "<leader>avd", ask(prompt.add_docstring),              desc = "Docstring (Ask)",                 mode = { "n", "v" } },
        { "<leader>avD", edit_submit(prompt.add_docstring),      desc = "Docstring (Edit)",                mode = "v" },
        { "<leader>avf", ask(prompt.fix_bugs),                   desc = "Fix Bugs (Ask)",                  mode = { "n", "v" } },
        { "<leader>avF", edit_submit(prompt.fix_bugs),           desc = "Fix Bugs (Edit)",                 mode = "v" },
        { "<leader>avu", ask(prompt.add_tests),                  desc = "Add Tests (Ask)",                 mode = { "n", "v" } },
        { "<leader>avU", edit_submit(prompt.add_tests),          desc = "Add Tests (Edit)",                mode = "v" },
        -- stylua: ignore end
      }
      vim.list_extend(keys, mappings)
    end,
    ---@type avante.Config
    opts = {
      mappings = {
        refresh = mapping_disabled_prefix .. "r",
        focus = mapping_disabled_prefix .. "f",
        toggle = {
          default = mapping_disabled_prefix .. "t",
          debug = mapping_disabled_prefix .. "d",
          hint = mapping_disabled_prefix .. "h",
          suggestion = "<leader>aS",
        },
        sidebar = {
          -- disable since <tab> is mapped to <C-w>w
          switch_windows = "<A-Down>",
          reverse_switch_windows = "<A-Up>",
          close = { "q" },
        },
        files = {
          add_current = "<leader>af",
        },
      },
      behaviour = {
        -- auto_suggestions = true, -- experimental
        -- enable_cursor_planning_mode = true,
        auto_apply_diff_after_generation = true,
      },
      provider = "copilot-claude", -- only recommend using claude
      auto_suggestions_provider = "groq", -- high-frequency, can be expensive if enabled
      -- cursor_applying_provider = "groq",
      -- copilot = { model = "claude-3.5-sonnet" },
      -- https://github.com/yetone/avante.nvim/wiki/Custom-providers
      vendors = {
        -- be able to switch between copilot (gpt-4o) and copilot-claude
        ---@type AvanteSupportedProvider
        ---@diagnostic disable-next-line: missing-fields
        ["copilot-claude"] = {
          __inherited_from = "copilot",
          -- https://github.com/CopilotC-Nvim/CopilotChat.nvim#models
          model = "claude-3.5-sonnet",
        },
        ---@type AvanteSupportedProvider
        ---@diagnostic disable-next-line: missing-fields
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          -- curl -L -X GET "https://api.deepseek.com/models" -H "Accept: application/json" -H "Authorization: Bearer $DEEPSEEK_API_KEY" | jq .
          model = "deepseek-reasoner",
        },
        -- https://github.com/yetone/avante.nvim/pull/159
        ---@type AvanteSupportedProvider
        ---@diagnostic disable-next-line: missing-fields
        groq = {
          __inherited_from = "openai",
          api_key_name = "GROQ_API_KEY",
          endpoint = "https://api.groq.com/openai/v1/",
          -- curl -X GET "https://api.groq.com/openai/v1/models" -H "Authorization: Bearer $GROQ_API_KEY" -H "Content-Type: application/json" | jq '.data | sort_by(.created)'
          model = "llama-3.3-70b-versatile",
          max_tokens = 32768,
        },
        ---@type AvanteSupportedProvider
        ---@diagnostic disable-next-line: missing-fields
        openrouter = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "deepseek/deepseek-r1",
        },
      },
      hints = { enabled = false },
    },
  },
  {
    "yetone/avante.nvim",
    optional = true,
    opts = function(_, opts)
      local picker = LazyVim.pick.picker.name
      if picker == "fzf" or picker == "snacks" then
        return U.extend_tbl(opts, {
          file_selector = {
            ---@type FileSelectorProvider
            provider = picker,
          },
        })
      end
    end,
  },

  -- {
  --   "saghen/blink.cmp",
  --   optional = true,
  --   dependencies = {
  --     {
  --       "saghen/blink.compat",
  --       opts = function()
  --         -- HACK: monkeypatch cmp.ConfirmBehavior for Avante
  --         require("cmp").ConfirmBehavior = {
  --           Insert = "insert",
  --           Replace = "replace",
  --         }
  --       end,
  --     },
  --   },
  --   opts = {
  --     sources = {
  --       compat = {
  --         "avante_commands",
  --         "avante_mentions",
  --         -- "avante_files",
  --       },
  --       providers = {
  --         avante_commands = {
  --           score_offset = 90,
  --         },
  --         avante_mentions = {
  --           score_offset = 1000,
  --         },
  --         -- avante_files = {
  --         --   score_offset = 100,
  --         -- },
  --       },
  --     },
  --   },
  -- },
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = "Kaiser-Yang/blink-cmp-avante",
    opts = {
      sources = {
        default = { "avante" },
        providers = {
          avante = {
            module = "blink-cmp-avante",
            name = "Avante",
          },
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
}
