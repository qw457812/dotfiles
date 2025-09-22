if vim.fn.executable("aider") == 0 then
  return {}
end

local toggle_key = "<M-/>"

return {
  {
    "GeorgesAlkhouri/nvim-aider",
    dependencies = "folke/snacks.nvim",
    cmd = "Aider",
    keys = {
      { toggle_key, "<cmd>Aider toggle<cr>", desc = "Open (Aider)" },
      { "<leader>ad=", "<cmd>Aider add<cr>", desc = "Add File" },
      { "<leader>ad-", "<cmd>Aider drop<cr>", desc = "Drop File" },
      { "<leader>ad+", "<cmd>Aider add readonly<cr>", desc = "Add Read-Only File" },
      { "<leader>adi", "<cmd>Aider send<cr>", desc = "Send", mode = { "n", "v" } },
      { "<leader>ad/", "<cmd>Aider command<cr>", desc = "Commands" },
      { "<leader>adb", "<cmd>Aider buffer<cr>", desc = "Send Buffer" },
      { "<leader>add", "<cmd>Aider buffer diagnostics<cr>", desc = "Send Buffer Diagnostics" },
      { "<leader>adr", "<cmd>Aider reset<cr>", desc = "Reset" },
    },
    opts = function()
      -- local defaults = require("nvim_aider.config").defaults

      return {
        -- -- see also:
        -- -- - ~/.aider.conf.yml
        -- -- - ~/.aider.model.settings.yml
        -- args = vim.list_extend(vim.deepcopy(defaults.args), {
        --   "--model",
        --   "gemini",
        -- }),
        auto_reload = true,
        ---@module "snacks"
        ---@type snacks.win.Config|{}
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
                  vim.api.nvim_feedkeys("a", "n", false) -- add this line for `--vim`
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
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          mode = { "n", "v" },
          { "<leader>ad", group = "aider", icon = { icon = "󰧑 ", color = "green" } },
        },
      },
    },
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
            local paths = vim.tbl_map(function(node)
              return node.path
            end, selected_nodes)
            if #paths > 0 then
              require("nvim_aider").api.add_file(table.concat(paths, " "))
            end
          end,
          nvim_aider_drop = function(state)
            local node = state.tree:get_node()
            require("nvim_aider").api.drop_file(node.path)
          end,
          nvim_aider_drop_visual = function(_, selected_nodes)
            local paths = vim
              .iter(selected_nodes)
              :map(function(node)
                return node.path
              end)
              :join(" ")
            if paths ~= "" then
              require("nvim_aider").api.drop_file(paths)
            end
          end,
          nvim_aider_add_read_only = function(state)
            local commands = require("nvim_aider.commands_slash")
            local terminal = require("nvim_aider.terminal")
            local node = state.tree:get_node()
            terminal.command(commands["read-only"].value, node.path)
          end,
          nvim_aider_add_read_only_visual = function(_, selected_nodes)
            local commands = require("nvim_aider.commands_slash")
            local terminal = require("nvim_aider.terminal")
            local paths = vim.tbl_map(function(node)
              return node.path
            end, selected_nodes)
            if #paths > 0 then
              terminal.command(commands["read-only"].value, table.concat(paths, " "))
            end
          end,
        },
        window = {
          mappings = {
            ["<localleader>="] = { "nvim_aider_add", desc = "Add (Aider)" },
            ["<localleader>-"] = { "nvim_aider_drop", desc = "Drop (Aider)" },
            ["<localleader>+"] = { "nvim_aider_add_read_only", desc = "Add As Read-only (Aider)" },
          },
        },
      },
    },
  },
}
