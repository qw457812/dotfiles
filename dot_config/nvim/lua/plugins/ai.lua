---@type LazySpec
return {
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = {
      root_dir = function()
        return LazyVim.root({ normalize = true })
      end,
      filetypes = { ["*"] = true },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = function()
      U.toggle.ai_cmps.copilot = Snacks.toggle({
        name = "Copilot",
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
  { "giuxtaposition/blink-cmp-copilot", optional = true, enabled = false, cond = false },
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "fang2hou/blink-copilot", shell_command_editor = true },
    opts = {
      sources = {
        providers = {
          copilot = {
            module = "blink-copilot",
          },
        },
      },
    },
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
  },
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
      if not LazyVim.has_extra("ai.codeium") then
        return
      end

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
        desc = "CopilotChat",
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
  },
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
}
