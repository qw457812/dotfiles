local mapping_disabled_prefix = "<leader>av<localleader>"

local avante_ft = { "Avante", "AvanteInput", "AvanteSelectedFiles" }

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

local function focus_input()
  local sidebar = require("avante").get()
  if sidebar then
    sidebar:focus_input()
    if vim.bo.filetype == "AvanteInput" then
      vim.cmd("noautocmd startinsert!")
    end
  end
end

---@param question? string|fun():string
---@return function
local function ask(question)
  return function()
    ---@diagnostic disable-next-line: need-check-nil
    question = vim.is_callable(question) and question() or question
    ---@cast question string

    local sidebar = require("avante").get()
    local input_orig ---@type string?
    local is_visual = U.is_visual_mode()
    if sidebar and sidebar:is_open() then
      if is_visual then
        input_orig = sidebar:get_input_value()
      elseif not question then
        focus_input()
        return
      end
    end

    require("avante.api").ask({ question = question })
    vim.schedule(function()
      if is_visual then
        U.stop_visual_mode()
        -- restore original input value for `v_<leader>aa`
        sidebar = require("avante").get()
        if sidebar and sidebar:is_open() and sidebar:get_input_value() == "" and input_orig then
          sidebar:set_input_value(input_orig)
        end
      end
      if not question then
        focus_input()
      end
    end)
  end
end

-- prefill edit window with common scenarios to avoid repeating query and submit immediately
---@param question string|fun():string
---@return function
local function edit_submit(question)
  return function()
    question = vim.is_callable(question) and question() or question
    ---@cast question string
    require("avante.api").edit()
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].filetype == "AvantePromptInput" then
        vim.cmd("stopinsert")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { question })
        vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { 1, #question + 1 })
        -- simulate <CR> keypress to submit
        vim.api.nvim_feedkeys(vim.keycode("<CR>"), "m", false)
      end
    end)
  end
end

local function switch_provider()
  -- https://github.com/yetone/avante.nvim/blob/e9ab2ca2fd7b8df4bed0963f490f59d8ed119ecb/plugin/avante.lua#L115-L123
  vim.ui.select(
    vim.tbl_keys(require("avante.config").providers),
    { prompt = "Select Avante Provider:" },
    function(choice)
      if choice then
        require("avante.api").switch_provider(choice)
      end
    end
  )
end

-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/completion/avante-nvim/init.lua
return {
  {
    "yetone/avante.nvim",
    -- lazy = false, -- see: https://github.com/yetone/avante.nvim/issues/561#issuecomment-2342550208
    build = vim.g.user_is_termux and "make BUILD_FROM_SOURCE=true" or "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
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
      { "MeanderingProgrammer/render-markdown.nvim", optional = true, ft = "Avante" },
    },
    cmd = "AvanteModels",
    keys = function(_, keys)
      local opts_mappings = LazyVim.opts("avante.nvim").mappings or {}
      -- stylua: ignore
      local mappings = {
        { mapping_disabled_prefix, "", desc = "+disabled" },
        { opts_mappings.ask or "<leader>aa", ask(), desc = "Avante", mode = { "n", "v" } },
        { "<leader>aA", function() require("avante.api").ask({ new_chat = true }) end, desc = "Avante New Chat", mode = { "n", "v" } },
        { opts_mappings.edit or "<leader>ae", function() require("avante.api").edit() end, desc = "Edit (Avante)", mode = "v" },
        { opts_mappings.select_history or "<leader>ah", function() require("avante.api").select_history() end, desc = "Pick History (Avante)" },
        { "<localleader>s", function() require("avante.api").stop() end, desc = "Stop", ft = avante_ft },
        { "<localleader>r", function() require("avante.api").refresh() end, desc = "Refresh", ft = avante_ft },
        { "<localleader>m", function() require("avante.api").select_model() end, desc = "Switch Model", ft = avante_ft },
        { "<localleader>c", "<cmd>AvanteClear<cr>", desc = "Clear", ft = avante_ft },
        { "<localleader>p", switch_provider, desc = "Switch Provider", ft = avante_ft },
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
      }
      vim.list_extend(keys, mappings)
    end,
    ---@type avante.Config
    opts = {
      mappings = {
        new_ask = mapping_disabled_prefix .. "n",
        refresh = mapping_disabled_prefix .. "r",
        focus = mapping_disabled_prefix .. "f",
        select_model = mapping_disabled_prefix .. "m",
        stop = mapping_disabled_prefix .. "s",
        toggle = {
          default = mapping_disabled_prefix .. "t",
          debug = mapping_disabled_prefix .. "d",
          hint = mapping_disabled_prefix .. "h",
          suggestion = "<leader>aS",
        },
        sidebar = {
          -- -- disable since <tab> is mapped to <C-w>w
          -- switch_windows = "<A-Down>",
          -- reverse_switch_windows = "<A-Up>",
          close_from_input = {
            normal = "q",
            insert = "<C-c>",
          },
        },
        files = {
          add_current = "<leader>af",
        },
      },
      behaviour = {
        -- auto_suggestions = true, -- experimental
        -- auto_apply_diff_after_generation = true,
        -- auto_focus_on_diff_view = true,
        -- enable_token_counting = false,
        -- use_cwd_as_project_root = true,
      },
      provider = "copilot_claude", -- only recommend using claude
      -- auto_suggestions_provider = "ollama", -- high-frequency, can be expensive if enabled
      -- https://github.com/yetone/cosmos-nvim/blob/64ffc3f90f33eb4049f1495ba49f086280dc8a1c/lua/layers/completion/plugins.lua#L249
      ---@type table<string, AvanteSupportedProvider>
      providers = {
        copilot = {
          model = "gpt-4.1",
        },
        ollama = {
          model = "llama3.2",
          hide_in_model_selector = true,
        },
        -- openai = { hide_in_model_selector = true },
        azure = { hide_in_model_selector = true },
        claude = { hide_in_model_selector = true },
        bedrock = { hide_in_model_selector = true },
        gemini = { hide_in_model_selector = true },
        vertex = { hide_in_model_selector = true },
        cohere = { hide_in_model_selector = true },
        vertex_claude = { hide_in_model_selector = true },
        copilot_claude = {
          __inherited_from = "copilot",
          model = "claude-sonnet-4",
        },
        copilot_claude_thought = {
          __inherited_from = "copilot",
          model = "claude-3.7-sonnet-thought",
          extra_request_body = {
            temperature = 1,
            max_tokens = 20000,
          },
        },
        copilot_gemini = {
          __inherited_from = "copilot",
          model = "gemini-2.5-pro",
        },
        -- deepseek = {
        --   __inherited_from = "openai",
        --   api_key_name = "DEEPSEEK_API_KEY",
        --   endpoint = "https://api.deepseek.com",
        --   -- curl -L -X GET "https://api.deepseek.com/models" -H "Accept: application/json" -H "Authorization: Bearer $DEEPSEEK_API_KEY" | jq .
        --   model = "deepseek-reasoner",
        --   disable_tools = true,
        -- },
        groq = {
          __inherited_from = "openai",
          api_key_name = "GROQ_API_KEY",
          endpoint = "https://api.groq.com/openai/v1/",
          -- curl -X GET "https://api.groq.com/openai/v1/models" -H "Authorization: Bearer $GROQ_API_KEY" -H "Content-Type: application/json" | jq '.data | sort_by(.created)'
          model = "llama-3.3-70b-versatile",
          extra_request_body = {
            max_tokens = 32768,
          },
          disable_tools = true,
        },
        openrouter_claude = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "anthropic/claude-sonnet-4",
        },
        openrouter_gemini = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "google/gemini-2.5-pro-preview",
        },
        ["claude-haiku"] = { hide_in_model_selector = true },
        ["claude-opus"] = { hide_in_model_selector = true },
        ["openai-gpt-4o-mini"] = { hide_in_model_selector = true },
        aihubmix = { hide_in_model_selector = true },
        ["aihubmix-claude"] = { hide_in_model_selector = true },
        ["bedrock-claude-3.7-sonnet"] = { hide_in_model_selector = true },
      },
      windows = {
        ---@type AvantePosition
        position = "smart",
        height = 50,
        sidebar_header = {
          align = vim.g.user_is_termux and "right" or nil,
        },
      },
      selector = {
        provider = ({ snacks = "snacks", fzf = "fzf_lua" })[LazyVim.pick.picker.name],
        exclude_auto_select = { "neo-tree" },
      },
      input = {
        provider = "snacks",
      },
      hints = { enabled = false },
    },
  },
  {
    "yetone/avante.nvim",
    optional = true,
    opts = function()
      LazyVim.on_load("avante.nvim", function()
        local snacks_util = require("snacks.util")
        local bg = vim.g.user_transparent_background and "#2f3a2f" or snacks_util.color("Normal", "bg")
        snacks_util.set_hl({
          AvanteSidebarWinSeparator = "WinSeparator",
          AvanteSidebarWinHorizontalSeparator = { fg = bg },
        })
      end)

      local augroup = vim.api.nvim_create_augroup("avante_keymaps", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = avante_ft,
        callback = function(ev)
          local buf = ev.buf
          local is_input = vim.bo[buf].filetype == "AvanteInput"

          vim.keymap.set("n", "<Esc>", function()
            if not U.keymap.clear_ui_esc({ popups = not is_input }) then
              vim.cmd.wincmd(vim.g.user_is_termux and "3k" or "h")
            end
          end, { buffer = buf, desc = "Clear UI or Unfocus (Avante)" })

          if is_input then
            vim.b[buf].user_blink_path = false
            vim.keymap.set("i", "<C-h>", "<Esc><C-w>h", { buffer = buf, desc = "Go to Left Window", remap = true })
            vim.keymap.set("i", "<C-k>", "<Esc><C-w>k", { buffer = buf, desc = "Go to Upper Window", remap = true })
          else
            vim.keymap.set("n", "i", focus_input, { buffer = buf, desc = "Focus Input (Avante)" })
            vim.api.nvim_create_autocmd("BufEnter", {
              group = augroup,
              buffer = buf,
              callback = function()
                vim.defer_fn(function()
                  if vim.api.nvim_get_current_buf() == buf and vim.api.nvim_get_mode().mode == "i" then
                    vim.cmd("stopinsert")
                  end
                end, 350)
              end,
            })
          end
        end,
      })
    end,
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = {
      {
        "saghen/blink.compat",
        opts = function()
          -- HACK: monkeypatch cmp.ConfirmBehavior for Avante
          require("cmp").ConfirmBehavior = {
            Insert = "insert",
            Replace = "replace",
          }
        end,
      },
    },
    opts = {
      sources = {
        compat = {
          "avante_commands",
          "avante_mentions",
          -- "avante_files",
        },
        providers = {
          avante_commands = {
            score_offset = 90,
          },
          avante_mentions = {
            score_offset = 100,
          },
          -- avante_files = {
          --   score_offset = 100,
          -- },
        },
      },
    },
  },
  -- {
  --   "saghen/blink.cmp",
  --   optional = true,
  --   dependencies = "Kaiser-Yang/blink-cmp-avante",
  --   opts = {
  --     sources = {
  --       default = { "avante" },
  --       providers = {
  --         avante = {
  --           module = "blink-cmp-avante",
  --         },
  --       },
  --     },
  --   },
  -- },
}
