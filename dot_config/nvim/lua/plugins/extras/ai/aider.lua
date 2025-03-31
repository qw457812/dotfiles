local toggle_key = "<C-cr>"

return {
  {
    "GeorgesAlkhouri/nvim-aider",
    enabled = vim.fn.executable("aider") == 1,
    dependencies = "folke/snacks.nvim",
    cmd = "AiderTerminalToggle",
    keys = {
      { toggle_key, "<cmd>AiderTerminalToggle<cr>", desc = "Open Terminal (Aider)" },
      { "<leader>as", "<cmd>AiderTerminalSend<cr>", desc = "Send (Aider)", mode = { "n", "v" } },
      { "<leader>a/", "<cmd>AiderQuickSendCommand<cr>", desc = "Send Command (Aider)" },
      { "<leader>ab", "<cmd>AiderQuickSendBuffer<cr>", desc = "Send Buffer (Aider)" },
      { "<leader>a+", "<cmd>AiderQuickAddFile<cr>", desc = "Add File (Aider)" },
      { "<leader>a-", "<cmd>AiderQuickDropFile<cr>", desc = "Drop File (Aider)" },
      { "<leader>ar", "<cmd>AiderQuickReadOnlyFile<cr>", desc = "Add Read-Only File (Aider)" },
    },
    opts = function()
      -- local defaults = require("nvim_aider.config").defaults

      return {
        -- -- moved to ~/.aider.conf.yml
        -- args = vim.list_extend(vim.deepcopy(defaults.args), {
        --   "--dark-mode",
        --   "--vim",
        --   -- "--verbose",
        --   "--model",
        --   "deepseek/deepseek-chat",
        -- }),
        ---@module "snacks"
        ---@type snacks.win.Config
        ---@diagnostic disable-next-line: missing-fields
        win = {
          position = "float",
          wo = {
            winbar = "",
          },
          b = {
            user_lualine_filename = "nvim-aider",
          },
          keys = {
            aider_close = {
              toggle_key,
              function(self)
                self:hide()
              end,
              mode = "t",
              desc = "Close",
            },
            -- copied from: https://github.com/folke/snacks.nvim/blob/98df370703b3c47a297988f3e55ce99628639590/lua/snacks/terminal.lua#L45
            term_normal = {
              "<esc>",
              function(self)
                ---@diagnostic disable-next-line: inject-field
                self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
                if self.esc_timer:is_active() then
                  self.esc_timer:stop()
                  vim.api.nvim_feedkeys(vim.keycode("a"), "n", false) -- add this line for `--vim`
                  vim.cmd("stopinsert")
                else
                  self.esc_timer:start(200, 0, function() end)
                  return "<esc>"
                end
              end,
              mode = "t",
              expr = true,
              desc = "Double escape to normal mode",
            },
          },
        },
      }
    end,
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      filesystem = {
        commands = {
          -- copied from: https://github.com/GeorgesAlkhouri/nvim-aider/blob/3554ffdd7f0f91167f83ab3e3475ba08a090061f/lua/nvim_aider/neo_tree.lua#L64-L97
          -- the `require("nvim_aider.neo_tree").setup(opts)` way breaks the lazy loading of both nvim-aider and neo-tree.nvim
          nvim_aider_add = function(state)
            local node = state.tree:get_node()
            require("nvim_aider").api.add_file(node.path)
          end,
          nvim_aider_add_visual = function(_, selected_nodes)
            local nodeNames = {}
            for _, node in pairs(selected_nodes) do
              table.insert(nodeNames, node.path)
            end
            if #nodeNames > 0 then
              require("nvim_aider").api.add_file(table.concat(nodeNames, " "))
            end
          end,
          nvim_aider_drop = function(state)
            local node = state.tree:get_node()
            require("nvim_aider").api.drop_file(node.path)
          end,
          nvim_aider_drop_visual = function(_, selected_nodes)
            local nodeNames = {}
            for _, node in pairs(selected_nodes) do
              table.insert(nodeNames, node.path)
            end
            if #nodeNames > 0 then
              require("nvim_aider").api.drop_file(table.concat(nodeNames, " "))
            end
          end,
        },
        window = {
          mappings = {
            ["+"] = { "nvim_aider_add", desc = "add to aider" },
            ["-"] = { "nvim_aider_drop", desc = "drop from aider" },
          },
        },
      },
    },
  },
}
