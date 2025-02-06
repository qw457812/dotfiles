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
      -- { "<leader>a/", "<cmd>AiderQuickSendCommand<cr>", desc = "Send Command (Aider)" }, -- telescope.nvim is required
      { "<leader>ab", "<cmd>AiderQuickSendBuffer<cr>", desc = "Send Buffer (Aider)" },
      { "<leader>a+", "<cmd>AiderQuickAddFile<cr>", desc = "Add File (Aider)" },
      { "<leader>a-", "<cmd>AiderQuickDropFile<cr>", desc = "Drop File (Aider)" },
      { "<leader>ar", "<cmd>AiderQuickReadOnlyFile<cr>", desc = "Add Read-Only File (Aider)" },
    },
    init = function()
      if not LazyVim.has("telescope.nvim") then
        -- HACK: disable loading nvim_aider.ui since it requires telescope.nvim, `AiderQuickSendCommand` will not be available
        package.loaded["nvim_aider.ui"] = true
      end
    end,
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
          keys = {
            aider_close = {
              toggle_key, -- <esc>
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
}
