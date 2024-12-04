return {
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = {
      filetypes = { ["*"] = true },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    optional = true,
    opts = function()
      Snacks.toggle({
        name = "Copilot Completion",
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
      }):map("<leader>uA")
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

  -- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/editing-support/copilotchat-nvim/init.lua
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    optional = true,
    dependencies = {
      {
        "MeanderingProgrammer/render-markdown.nvim",
        optional = true,
        ft = (function()
          local plugin = LazyVim.get_plugin("render-markdown.nvim")
          local ft = plugin and plugin.ft or { "markdown" }
          ft = type(ft) == "table" and ft or { ft }
          ft = vim.deepcopy(ft)
          table.insert(ft, "copilot-chat")
          return ft
        end)(),
      },
    },
    opts = {
      -- -- render-markdown integration | https://github.com/CopilotC-Nvim/CopilotChat.nvim#tips
      -- highlight_headers = false,
      -- separator = "---",
      -- error_header = "> [!ERROR] Error",
      error_header = LazyVim.config.icons.diagnostics.Error .. " Error ",
      question_header = "  User ",
      -- model = "claude-3.5-sonnet",
      -- show_help = false,
    },
  },
}
