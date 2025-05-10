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
    cmd = { "CopilotChatModels", "CopilotChatPrompts", "CopilotChatAgents" },
    dependencies = {
      {
        "MeanderingProgrammer/render-markdown.nvim",
        optional = true,
        ft = U.markdown.render_markdown_ft("copilot-chat"),
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>aa", mode = { "n", "v" }, false },
      { "<leader>ax", mode = { "n", "v" }, false },
      { "<leader>ac", mode = { "n", "v" }, function() require("CopilotChat").open() end, desc = "CopilotChat" },
      { "<localleader>c", mode = { "n", "v" }, function() require("CopilotChat").reset() end, desc = "Clear", ft = "copilot-chat" },
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
        error_header = LazyVim.config.icons.diagnostics.Error .. " Error ",
        question_header = "  User ",
        -- model = "claude-3.7-sonnet",
        -- show_help = false,
        window = {
          layout = function()
            return vim.o.columns >= 120 and "vertical" or "horizontal"
          end,
        },
      })
    end,
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
