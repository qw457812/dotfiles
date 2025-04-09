-- https://github.com/yetone/cosmos-nvim/blob/64ffc3f90f33eb4049f1495ba49f086280dc8a1c/lua/layers/completion/plugins.lua#L194
-- https://github.com/AstroNvim/astrocommunity/blob/438fdb8c648bc8870bab82e9149cad595ddc7a67/lua/astrocommunity/editing-support/mcphub-nvim/init.lua
return {
  {
    "ravitemer/mcphub.nvim",
    cmd = "MCPHub",
    build = "npm install -g mcp-hub@latest",
    keys = {
      { "<leader>am", "<cmd>MCPHub<cr>", desc = "MCP Hub" },
    },
    opts = {
      log = {
        level = vim.log.levels.WARN,
      },
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
}
