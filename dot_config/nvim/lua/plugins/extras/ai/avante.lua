local mapping_disabled_prefix = "<leader>av<localleader>"

local avante_ft = { "Avante", "AvanteInput", "AvanteSelectedFiles", "AvanteSelectedCode" }

-- https://github.com/yetone/avante.nvim/wiki/Recipe-and-Tricks
---@type table<string, string|fun():string>
local prompts = {
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
---@type LazySpec
return {
  {
    "yetone/avante.nvim",
    build = vim.g.user_is_termux and "make BUILD_FROM_SOURCE=true" or "make",
    dependencies = {
      "MunifTanjim/nui.nvim",
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
        { "<leader>av",                                 "",                                                            desc = "+avante",                         mode = { "n", "v" } },
        { mapping_disabled_prefix,                      "",                                                            desc = "+disabled" },
        { opts_mappings.ask or "<leader>aa",            ask(),                                                         desc = "Chat",                            mode = { "n", "v" } },
        { opts_mappings.new_ask or "<leader>an",        function() require("avante.api").ask({ new_chat = true }) end, desc = "New Chat",                        mode = { "n", "v" } },
        { opts_mappings.edit or "<leader>ae",           function() require("avante.api").edit() end,                   desc = "Edit",                            mode = "v" },
        { opts_mappings.select_history or "<leader>ah", function() require("avante.api").select_history() end,         desc = "Pick History" },
        { opts_mappings.zen_mode or "<leader>az",       function() require("avante.api").zen_mode() end,               desc = "Zen Mode",                        mode = { "n", "v" } },
        { opts_mappings.toggle.repomap or "<leader>aR", function() require("avante.repo_map").show() end,              desc = "Display Repo Map" },
        { "<localleader>s",                             function() require("avante.api").stop() end,                   desc = "Stop",                            ft = avante_ft },
        { "<localleader>r",                             function() require("avante.api").refresh() end,                desc = "Refresh",                         ft = avante_ft },
        { "<localleader>m",                             function() require("avante.api").select_model() end,           desc = "Switch Model",                    ft = avante_ft },
        { "<localleader>c",                             "<cmd>AvanteClear<cr>",                                        desc = "Clear",                           ft = avante_ft },
        { "<localleader>p",                             switch_provider,                                               desc = "Switch Provider",                 ft = avante_ft },
        { "<leader>avg",                                ask(prompts.grammar_correction),                               desc = "Grammar Correction (Ask)",        mode = { "n", "v" } },
        { "<leader>avG",                                edit_submit(prompts.grammar_correction),                       desc = "Grammar Correction (Edit)",       mode = "v" },
        { "<leader>avr",                                ask(prompts.code_readability_analysis),                        desc = "Code Readability Analysis (Ask)", mode = { "n", "v" } },
      }
      return vim.list_extend(keys, mappings)
    end,
    ---@type avante.Config
    opts = {
      mappings = {
        ask = "<leader>avv",
        new_ask = "<leader>avn",
        zen_mode = "<leader>avz",
        edit = "<leader>ave",
        select_history = "<leader>avh",
        refresh = mapping_disabled_prefix .. "r",
        focus = mapping_disabled_prefix .. "f",
        select_model = mapping_disabled_prefix .. "m",
        stop = mapping_disabled_prefix .. "s",
        toggle = {
          repomap = "<leader>avR",
          default = mapping_disabled_prefix .. "t",
          debug = mapping_disabled_prefix .. "d",
          hint = mapping_disabled_prefix .. "h",
          selection = mapping_disabled_prefix .. "C",
          suggestion = mapping_disabled_prefix .. "S",
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
          add_current = "<leader>av=",
          add_all_buffers = mapping_disabled_prefix .. "B",
        },
      },
      behaviour = {
        -- auto_suggestions = true, -- experimental
        -- auto_apply_diff_after_generation = true,
        -- auto_focus_on_diff_view = true,
        enable_token_counting = false,
        -- use_cwd_as_project_root = true,
      },
      provider = not vim.g.user_is_termux and vim.fn.executable("claude") == 1 and "claude-code" or "copilot",
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
          model = "google/gemini-2.5-pro",
        },
        openrouter_kimi = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "moonshotai/kimi-k2",
        },
        ["claude-haiku"] = { hide_in_model_selector = true },
        ["claude-opus"] = { hide_in_model_selector = true },
        ["openai-gpt-4o-mini"] = { hide_in_model_selector = true },
        aihubmix = { hide_in_model_selector = true },
        ["aihubmix-claude"] = { hide_in_model_selector = true },
      },
      ---@type table<string, AvanteACPProvider|{}>
      acp_providers = {
        ["claude-code"] = {
          env = U.ai.claude.provider.plan.synthetic,
        },
      },
      windows = {
        ------@type AvantePosition
        ---position = "smart",
        width = 40,
        height = 50,
        sidebar_header = {
          -- align = vim.g.user_is_termux and "right" or nil,
        },
      },
      selector = {
        provider = ({ snacks = "snacks", fzf = "fzf_lua" })[LazyVim.pick.picker.name],
        exclude_auto_select = { "neo-tree" },
      },
      input = {
        provider = "snacks",
      },
      selection = {
        hint_display = "none",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          mode = { "n", "v" },
          { "<leader>av", group = "avante", icon = { icon = " ", color = "grey" } },
          { mapping_disabled_prefix, group = "disabled" },
        },
      },
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
              -- vim.cmd.wincmd(vim.g.user_is_termux and "3k" or "h")
              vim.cmd.wincmd("h")
            end
          end, { buffer = buf, desc = "Clear UI or Unfocus (Avante)" })

          if is_input then
            vim.b[buf].user_blink_path = false
            vim.defer_fn(function()
              vim.keymap.set("i", "<C-h>", "<Esc><C-w>h", { buffer = buf, desc = "Go to Left Window", remap = true })
              -- vim.keymap.set("i", "<C-k>", "<Esc><C-w>k", { buffer = buf, desc = "Go to Upper Window", remap = true })
            end, 100) -- prevent <C-h> from being remapped by blink.nvim, since the `fallback` command in `{ "show_signature", "hide_signature", "fallback" }` appears to be unreachable
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
          "avante_shortcuts",
          -- "avante_files",
        },
        providers = {
          avante_commands = {
            score_offset = 90,
          },
          avante_mentions = {
            score_offset = 100,
          },
          avante_shortcuts = {
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
