-- https://github.com/AstroNvim/astrocommunity/blob/438fdb8c648bc8870bab82e9149cad595ddc7a67/lua/astrocommunity/editing-support/mcphub-nvim/init.lua
-- https://github.com/nzlov/LazyVim/blob/274dc6b4bb39184ee330633df3ca0cf47e2fa754/lua/plugins/avante.lua#L156
return {
  {
    "ravitemer/mcphub.nvim",
    cmd = "MCPHub",
    build = "npm install -g mcp-hub@latest",
    keys = {
      { "<leader>am", "<cmd>MCPHub<cr>", desc = "MCP Hub" },
    },
    ---@module "mcphub"
    ---@type MCPHub.Config
    opts = {
      -- log = { level = vim.log.levels.WARN },
    },
  },

  {
    "yetone/avante.nvim",
    optional = true,
    opts = {
      system_prompt = function()
        local hub = require("mcphub").get_hub_instance()
        return hub and hub:get_active_servers_prompt()
      end,
      custom_tools = function()
        return {
          require("mcphub.extensions.avante").mcp_tool(),
        }
      end,
    },
  },

  {
    "olimorris/codecompanion.nvim",
    optional = true,
    opts = {
      extensions = {
        mcphub = {
          callback = "mcphub.extensions.codecompanion",
          opts = {
            show_result_in_chat = true,
            make_vars = true,
            make_slash_commands = true,
          },
        },
      },
    },
  },
}
