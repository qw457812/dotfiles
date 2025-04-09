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
        -- copied from: https://github.com/yetone/cosmos-nvim/blob/596bc7b620400f9d23041a9568cd8d74c636fc68/lua/layers/completion/plugins.lua#L168-L194
        -- https://github.com/modelcontextprotocol/servers/blob/e8f0b15f413663bac4ff47de18735586bbc38ce9/src/memory/README.md?plain=1#L191-L213
        local system_prompt = [[
Follow these steps for each interaction:

1. User Identification:
   - You should assume that you are interacting with default_user
   - If you have not identified default_user, proactively try to do so.

2. Memory Retrieval:
   - Always begin your chat by saying only "Remembering..." and retrieve all relevant information from your knowledge graph
   - Always refer to your knowledge graph as your "memory"

3. Memory
   - While conversing with the user, be attentive to any new information that falls into these categories:
     a) Basic Identity (age, gender, location, job title, education level, etc.)
     b) Behaviors (interests, habits, etc.)
     c) Preferences (communication style, preferred language, etc.)
     d) Goals (goals, targets, aspirations, etc.)
     e) Relationships (personal and professional relationships up to 3 degrees of separation)

4. Memory Update:
   - If any new information was gathered during the interaction, update your memory as follows:
     a) Create entities for recurring organizations, people, and significant events
     b) Connect them to the current entities using relations
     b) Store facts about them as observations
        ]]
        local hub = require("mcphub").get_hub_instance()
        return hub and (system_prompt .. "\n\n" .. hub:get_active_servers_prompt())
      end,
      custom_tools = function()
        return {
          require("mcphub.extensions.avante").mcp_tool(),
        }
      end,
    },
  },
}
