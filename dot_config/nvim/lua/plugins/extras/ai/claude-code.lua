if vim.fn.executable("claude") == 0 then
  return {}
end

local toggle_key = "<C-,>"

---@param buf? integer
local function is_claude(buf)
  buf = buf or 0
  return vim.bo[buf].filetype == "snacks_terminal" and vim.api.nvim_buf_get_name(buf):match("^term://.*:claude$")
end

---@module "lazy"
---@type LazySpec
return {
  {
    "coder/claudecode.nvim",
    dependencies = {
      "folke/snacks.nvim",
      ---@module "snacks"
      ---@type snacks.Config
      opts = {
        terminal = {
          win = {
            keys = {
              claude_close = {
                toggle_key,
                function(self)
                  self:hide()
                end,
                mode = "t",
                desc = "Close",
              },
              -- copied from: https://github.com/folke/snacks.nvim/blob/bc0630e43be5699bb94dadc302c0d21615421d93/lua/snacks/terminal.lua#L49-L64
              term_normal = {
                "<esc>",
                function(self)
                  ---@diagnostic disable-next-line: inject-field
                  self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
                  if self.esc_timer:is_active() then
                    self.esc_timer:stop()
                    if is_claude(self.buf) then
                      vim.api.nvim_feedkeys(vim.keycode("i"), "n", false) -- for vim mode of claude code
                    end
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
        },
      },
    },
    cmd = "ClaudeCode",
    keys = {
      -- stylua: ignore
      { toggle_key, function() vim.cmd(is_claude() and "ClaudeCode" or "ClaudeCodeFocus") end, desc = "Claude Code" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume (Claude)" },
      { "<leader>a.", "<cmd>ClaudeCode --continue<cr>", desc = "Continue (Claude)" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add Buffer (Claude)" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", desc = "Send (Claude)", mode = "x" },
      { "=", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add File (Claude)", mode = { "n", "x" }, ft = "neo-tree" },
      { "<localleader>=", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add File (Claude)", ft = "oil" },
      { "<M-space>", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Diff (Claude)" },
      { "<M-cr>", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Diff (Claude)" },
    },
    init = function()
      -- see: https://github.com/coder/claudecode.nvim/issues/52#issuecomment-2993522840
      vim.env.CLAUDE_CONFIG_DIR = vim.fn.expand("~/.config/claude")
    end,
    opts = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*:claude",
        callback = function(ev)
          if vim.bo[ev.buf].filetype == "snacks_terminal" then
            vim.b[ev.buf].user_lualine_filename = "claude_code"
          end
        end,
      })

      return {
        terminal = {
          split_width_percentage = 0.4,
        },
      }
    end,
  },

  {
    "wasabeef/yank-for-claude.nvim",
    -- stylua: ignore
    keys = {
      { "<leader>ay", function() require("yank-for-claude").yank_visual() end, desc = "Yank (Claude)", mode = "x" },
      { "<leader>ay", function() require("yank-for-claude").yank_line() end, desc = "Yank Line (Claude)" },
      { "<leader>aY", function() require("yank-for-claude").yank_visual_with_content() end, desc = "Yank With Content (Claude)", mode = "x" },
      { "<leader>aY", function() require("yank-for-claude").yank_line_with_content() end, desc = "Yank Line With Content (Claude)" },
    },
    opts = {},
  },
}
