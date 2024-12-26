if not (LazyVim.has("telescope.nvim") and vim.fn.executable("aider") == 1) then
  return {}
end

local toggle_key = "<C-cr>"

-- https://github.com/LazyVim/LazyVim/pull/5233
return {
  {
    "GeorgesAlkhouri/nvim-aider",
    dependencies = {
      "folke/snacks.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = {
      "AiderTerminalToggle",
    },
    -- stylua: ignore
    keys = {
      { toggle_key,   "<cmd>AiderTerminalToggle<cr>",   desc = "Open Terminal (Aider)" },
      { "<leader>ai", "<cmd>AiderTerminalToggle<cr>",   desc = "Open Terminal (Aider)" },
      { "<leader>as", "<cmd>AiderTerminalSend<cr>",     desc = "Send (Aider)", mode = { "n", "v" } },
      { "<leader>a/", "<cmd>AiderQuickSendCommand<cr>", desc = "Send Command (Aider)" },
      { "<leader>ab", "<cmd>AiderQuickSendBuffer<cr>",  desc = "Send Buffer (Aider)" },
      { "<leader>a+", "<cmd>AiderQuickAddFile<cr>",     desc = "Add File (Aider)" },
      { "<leader>a-", "<cmd>AiderQuickDropFile<cr>",    desc = "Drop File (Aider)" },
    },

    opts = function()
      local defaults = require("nvim_aider.config").defaults

      Snacks.config.style(defaults.win.style, {
        keys = {
          aider_close = {
            toggle_key, -- <esc>
            function(self)
              self:hide()
            end,
            mode = "t",
            desc = "Close",
          },
        },
      })

      return {
        args = vim.list_extend(vim.deepcopy(defaults.args), {
          "--model",
          "groq/llama-3.3-70b-versatile",
        }),
        win = {
          position = "float",
        },
      }
    end,
  },
}
