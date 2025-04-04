return {
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = {
      copilot_model = "gpt-4o-copilot",
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
      -- HACK: https://github.com/LazyVim/LazyVim/blob/8f4e9b8c1e43e354d91529484aedca54f04bdcf6/lua/lazyvim/plugins/extras/ai/copilot.lua#L54
      ---@diagnostic disable-next-line: inject-field
      require("copilot.api").status = require("copilot.status")

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
  { "giuxtaposition/blink-cmp-copilot", optional = true, enabled = false },
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "fang2hou/blink-copilot" },
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

      -- local orig_is_available = Source.is_available
      -- ---@diagnostic disable-next-line: duplicate-set-field
      -- function Source:is_available()
      --   return not vim.g.user_codeium_disable and orig_is_available(self)
      -- end
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

  -- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/editing-support/copilotchat-nvim/init.lua
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
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "copilot-chat",
        callback = function(ev)
          -- see: https://github.com/LazyVim/LazyVim/pull/5754
          -- path sources triggered by "/" interfere with CopilotChat commands
          vim.b[ev.buf].user_blink_path = false
        end,
      })

      return U.extend_tbl(opts, {
        -- -- render-markdown integration | https://github.com/CopilotC-Nvim/CopilotChat.nvim#tips
        -- highlight_headers = false,
        -- separator = "---",
        -- error_header = "> [!ERROR] Error",
        error_header = LazyVim.config.icons.diagnostics.Error .. " Error ",
        question_header = "  User ",
        -- model = "claude-3.7-sonnet",
        -- show_help = false,
      })
    end,
  },
}
