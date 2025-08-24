if vim.fn.executable("opencode") == 0 then
  return {}
end

local toggle_key = "<M-,>"

---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        toggle_key,
        function()
          U.terminal("opencode", {
            win = {
              keys = {
                opencode_close = {
                  toggle_key,
                  function(self)
                    self:hide()
                  end,
                  mode = "t",
                  desc = "Close",
                },
              },
              b = { user_lualine_filename = "opencode" },
              height = vim.g.user_is_termux and U.snacks.win.fullscreen_height or nil,
              width = vim.g.user_is_termux and 0 or nil,
            },
            cwd = LazyVim.root(),
          })
        end,
        desc = "opencode",
      },
    },
  },

  -- {
  --   "NickvanDyke/opencode.nvim",
  --   dependencies = "folke/snacks.nvim",
  --   keys = {
  --     {
  --       toggle_key,
  --       function()
  --         U.terminal("opencode", {
  --           win = {
  --             keys = {
  --               opencode_close = {
  --                 toggle_key,
  --                 function(self)
  --                   self:hide()
  --                 end,
  --                 mode = "t",
  --                 desc = "Close",
  --               },
  --             },
  --           },
  --           cwd = LazyVim.root(), -- TODO: check: https://github.com/NickvanDyke/opencode.nvim/blob/df3bdb794ca9369c90c3d8bc24644341f10810f8/lua/opencode.lua#L26
  --         })
  --       end,
  --       desc = "opencode",
  --     },
  --     -- TODO: not working
  --     -- stylua: ignore start
  --     { "<leader>aoa", function() require("opencode").ask() end, desc = "Ask", mode = { "n", "v" } },
  --     { "<leader>aoA", function() require("opencode").ask("@file ") end, desc = "Ask about current file", mode = { "n", "v" } },
  --     { "<leader>aoe", function() require("opencode").prompt("Explain @cursor and its context") end, desc = "Explain code near cursor" },
  --     { "<leader>aor", function() require("opencode").prompt("Review @file for correctness and readability") end, desc = "Review file" },
  --     { "<leader>aof", function() require("opencode").prompt("Fix these @diagnostics") end, desc = "Fix errors" },
  --     { "<leader>aod", function() require("opencode").prompt("Add documentation comments for @selection") end, desc = "Document selection", mode = "v" },
  --     { "<leader>aot", function() require("opencode").prompt("Add tests for @selection") end, desc = "Test selection", mode = "v" },
  --     -- stylua: ignore end
  --     {
  --       "<leader>aoo",
  --       function()
  --         require("opencode").prompt("Optimize @selection for performance and readability")
  --       end,
  --       desc = "Optimize selection",
  --       mode = "v",
  --     },
  --   },
  --   ---@type opencode.Config
  --   opts = {},
  --   specs = {
  --     {
  --       "folke/which-key.nvim",
  --       opts = {
  --         spec = {
  --           {
  --             mode = { "n", "v" },
  --             { "<leader>ao", group = "opencode" },
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },
}
