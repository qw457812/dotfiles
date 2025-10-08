---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      local servers = opts.servers
      if servers.copilot then
        servers.copilot = servers.copilot == true and {} or servers.copilot
        servers.copilot.root_dir = function(bufnr, on_dir)
          local root = LazyVim.root({ buf = bufnr })
          on_dir(root ~= vim.uv.cwd() and root or vim.fs.root(bufnr, vim.lsp.config.copilot.root_markers))
        end

        if servers.copilot.enabled ~= false then
          U.toggle.ai_cmps.copilot = Snacks.toggle({
            name = "copilot-language-server",
            get = function()
              return vim.lsp.is_enabled("copilot")
            end,
            set = function(state)
              vim.lsp.enable("copilot", state)
            end,
          })
        end
      end
    end,
  },

  {
    "folke/sidekick.nvim",
    optional = true,
    event = "LazyFile",
    keys = function(_, keys)
      if vim.g.user_distinguish_ctrl_i_tab or vim.g.user_is_termux then
        table.insert(keys, {
          "<tab>",
          LazyVim.cmp.map({ "ai_nes" }, function()
            vim.cmd("wincmd w")
          end),
          desc = "Jump/Apply Next Edit Suggestions or Next Window (sidekick)",
        })
      end
      -- stylua: ignore
      vim.list_extend(keys, {
        { "<leader>aa", false },
        { "<leader>as", false },
        { "<leader>af", false },
        { "<leader>av", false, mode = "x" },
        { "<leader>at", false, mode = { "n", "x" } },
        { "<leader>ap", false, mode = { "n", "x" } },
        { "<c-.>", false, mode = { "n", "x", "i", "t" } },
        { "<M-,>", function() require("sidekick.cli").toggle() end, mode = { "n", "x", "t" }, desc = "Sidekick Toggle" },
        { "<leader>ak", function() require("sidekick.cli").toggle() end, desc = "Sidekick Toggle CLI" },
        { "<leader>ass", function() require("sidekick.cli").select() end, desc = "Select CLI" },
        { "<leader>ass", function() require("sidekick.cli").send({ msg = "{selection}" }) end, mode = "x", desc = "Send Visual Selection" },
        { "<leader>ast", function() require("sidekick.cli").send({ msg = "{this}" }) end, mode = { "n", "x" }, desc = "Send This" },
        { "<leader>asf", function() require("sidekick.cli").send({ msg = "{file}" }) end, desc = "Send File" },
        { "<leader>asp", function() require("sidekick.cli").prompt() end, mode = { "n", "x" }, desc = "Select Prompt" },
        { "<leader>asc", function() require("sidekick.cli").toggle({ name = "claude" }) end, desc = "Claude" },
        { "<leader>asx", function() require("sidekick.cli").toggle({ name = "codex" }) end, desc = "Codex" },
      })
      return keys
    end,
    ---@module "sidekick"
    ---@type sidekick.Config
    opts = {
      nes = {
        clear = {
          esc = false, -- handled by U.keymap.clear_ui_esc()
        },
      },
      cli = {
        ---@type sidekick.win.Opts
        win = {
          layout = vim.g.user_is_termux and "bottom" or "right", ---@type "float"|"left"|"bottom"|"top"|"right"
          ---@type table<string, sidekick.cli.Keymap|false>
          keys = {
            blur_t = { "<c-o>", "blur" },
            blur_n = {
              "<esc>",
              function(t)
                if not U.keymap.clear_ui_esc() then
                  t:blur()
                end
              end,
              desc = "Clear UI or Blur",
              mode = "n",
            },
          },
        },
        ---@type sidekick.cli.Mux
        mux = {
          enabled = true,
        },
        ---@type table<string, sidekick.cli.Config|{}>
        tools = {
          claude = {
            env = {
              __IS_CLAUDECODE_NVIM = "1", -- flag to disable claude code statusline in ~/.claude/settings.json
              NVIM_FLATTEN_NEST = "1", -- allow "ctrl-g to edit prompt in nvim" to be nested for flatten.nvim
              ANTHROPIC_BASE_URL = vim.env.CTOK_BASE_URL,
              ANTHROPIC_AUTH_TOKEN = vim.env.CTOK_AUTH_TOKEN,
            },
            keys = {
              blur_t = false, -- claude code uses <c-o> for its own functionality
            },
          },
        },
      },
    },
    specs = {
      vim.g.ai_cmp and not LazyVim.has_extra("ai.copilot") and {
        "saghen/blink.cmp",
        optional = true,
        dependencies = "fang2hou/blink-copilot",
        opts = {
          sources = {
            default = { "copilot" },
            providers = {
              copilot = {
                module = "blink-copilot",
                score_offset = 100,
                async = true,
              },
            },
          },
        },
      } or { import = "foobar", enabled = false }, -- dummy import
      {
        "folke/which-key.nvim",
        opts = {
          spec = {
            {
              mode = { "n", "x" },
              { "<leader>as", group = "sidekick" },
            },
          },
        },
      },
    },
  },
  {
    "folke/sidekick.nvim",
    optional = true,
    opts = function()
      U.toggle.ai_cmps.sidekick_nes = Snacks.toggle({
        name = "Sidekick NES",
        get = function()
          -- https://github.com/folke/sidekick.nvim/blob/302cec770ca0a4b7dfafd7879034d33320592b33/lua/sidekick/nes/init.lua#L53-L55
          return require("sidekick.nes").enabled
        end,
        set = function(state)
          require("sidekick.nes").enable(state)
        end,
      })
    end,
  },

  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = {
      root_dir = function()
        return LazyVim.root()
      end,
      filetypes = { ["*"] = true },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = function()
      U.toggle.ai_cmps.copilot_lua = Snacks.toggle({
        name = "copilot.lua",
        get = function()
          return not require("copilot.client").is_disabled()
        end,
        set = function(state)
          if state then
            require("copilot.command").enable()
          else
            require("copilot.command").disable()
          end
        end,
      })
    end,
  },

  {
    "Exafunction/codeium.nvim",
    optional = true,
    opts = function()
      local Source = require("codeium.source")

      U.toggle.ai_cmps.codeium = Snacks.toggle({
        name = "Codeium",
        get = function()
          return not vim.g.user_codeium_disable
        end,
        set = function(state)
          vim.g.user_codeium_disable = not state
        end,
      })

      -- HACK: toggle, see: https://github.com/Exafunction/codeium.nvim/issues/136#issuecomment-2127891793
      Source.is_available = U.patch_func(Source.is_available, function(orig, self)
        return not vim.g.user_codeium_disable and orig(self)
      end)
    end,
    specs = {
      {
        "nvim-cmp",
        optional = true,
        opts = function(_, opts)
          for _, source in ipairs(opts.sources or {}) do
            if source.name == "codeium" then
              source.priority = 99 -- lower than copilot
              break
            end
          end
        end,
      },
      {
        "saghen/blink.cmp",
        optional = true,
        opts = function(_, opts)
          if vim.tbl_get(opts, "sources", "providers", "codeium", "score_offset") then
            opts.sources.providers.codeium.score_offset = 99 -- lower than copilot
          end
        end,
      },
      {
        "folke/noice.nvim",
        optional = true,
        opts = function(_, opts)
          opts.routes = vim.list_extend(opts.routes or {}, {
            {
              filter = {
                event = "msg_show",
                find = "^%[codeium/codeium%] ",
              },
              opts = { skip = true },
            },
            {
              filter = {
                event = "notify",
                find = "^completion request failed$",
              },
              opts = { skip = true },
            },
          })
        end,
      },
    },
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    optional = true,
    cmd = { "CopilotChatModels", "CopilotChatPrompts" },
    dependencies = {
      { "MeanderingProgrammer/render-markdown.nvim", optional = true, ft = "copilot-chat" },
    },
    -- stylua: ignore
    keys = {
      { "<leader>aa", mode = { "n", "v" }, false },
      { "<leader>ax", mode = { "n", "v" }, false },
      { "<leader>ap", mode = { "n", "v" }, false },
      { "<leader>aq", mode = { "n", "v" }, false },
      {
        "<leader>app",
        mode = { "n", "v" },
        function()
          local copilot_chat = require("CopilotChat")
          copilot_chat.open()

          -- copied from: https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/294bcb620ff66183e142cd8a43a7c77d5bc77a16/lua/CopilotChat/ui/chat.lua#L366-L375
          local chat = copilot_chat.chat
          if chat:focused() and vim.bo[chat.bufnr].modifiable then
            vim.cmd("startinsert!") -- add `!`
          end
        end,
        desc = "Chat",
      },
      { "<leader>apa", function() require("CopilotChat").select_prompt() end, desc = "Prompt Actions", mode = { "n", "v" } },
      { "<localleader>c", function() require("CopilotChat").reset() end, desc = "Clear", mode = { "n", "v" }, ft = "copilot-chat" },
      { "<localleader>m", "<cmd>CopilotChatModels<cr>", desc = "Switch Model", ft = "copilot-chat" },
      { "<localleader>s", "<cmd>CopilotChatStop<cr>", desc = "Stop", ft = "copilot-chat" },
    },
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "copilot-chat",
        callback = function(ev)
          -- see: https://github.com/LazyVim/LazyVim/pull/5754
          -- path sources triggered by "/" interfere with CopilotChat commands
          vim.b[ev.buf].user_blink_path = false

          vim.keymap.set(
            "n",
            "<Esc>",
            U.keymap.clear_ui_or_unfocus_esc,
            { buffer = ev.buf, desc = "Clear UI or Unfocus (CopilotChat)" }
          )
        end,
      })

      return U.extend_tbl(opts, {
        -- model = "claude-sonnet-4",
        -- show_help = false,
        language = "Chinese",
        -- stylua: ignore
        mappings = {
          reset            = { normal = "<localleader>c"  },
          toggle_sticky    = { normal = "<localleader>p"  },
          clear_stickies   = { normal = "<localleader>x"  },
          accept_diff      = { normal = "<localleader>a"  },
          jump_to_diff     = { normal = "<localleader>j"  },
          quickfix_answers = { normal = "<localleader>qa" },
          quickfix_diffs   = { normal = "<localleader>qd" },
          yank_diff        = { normal = "<localleader>y"  },
          show_diff        = { normal = "<localleader>d"  },
          show_info        = { normal = "<localleader>i"  },
          show_help        = { normal = "g?"              },
        },
        headers = {
          user = "##   User ",
          assistant = "##   Copilot ",
          tool = "## 󱁤  Tool ",
        },
        window = {
          layout = function()
            return vim.o.columns >= 120 and "vertical" or "horizontal"
          end,
        },
      } --[[@as CopilotChat.config.Config]])
    end,
    specs = {
      {
        "folke/which-key.nvim",
        opts = {
          spec = {
            {
              mode = { "n", "v" },
              { "<leader>ap", group = "copilot" },
            },
          },
        },
      },
      {
        "folke/edgy.nvim",
        optional = true,
        opts = function(_, opts)
          if vim.o.columns >= 120 then
            return
          end
          opts.right = opts.right or {}
          local copilot_chat_view
          for i, view in ipairs(opts.right) do
            if view.ft == "copilot-chat" then
              copilot_chat_view = table.remove(opts.right, i)
              break
            end
          end
          if copilot_chat_view then
            opts.bottom = opts.bottom or {}
            copilot_chat_view.size = { height = 0.4 }
            table.insert(opts.bottom, copilot_chat_view)
          end
        end,
      },
    },
  },
}
