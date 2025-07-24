if vim.fn.executable("claude") == 0 then
  return {}
end

local H = {}

H.toggle_key = "<C-,>"

---@param buf? integer
function H.is_cc(buf)
  buf = buf or 0
  return vim.bo[buf].filetype == "snacks_terminal" and vim.api.nvim_buf_get_name(buf):match("^term://.*:claude")
end

---Whether the claude code is in his own normal mode.
---@param buf? integer
---@return boolean?
function H.is_cc_norm(buf)
  buf = buf or 0
  if not H.is_cc(buf) then
    return false
  end

  local has_input_prompt = false
  local lines = vim.api.nvim_buf_get_lines(buf, -50, -1, false)
  for i, line in ipairs(lines) do
    -- selecting, not inputting
    -- - `│ ❯ Editor mode                               vim                                 │` of `/config`
    -- - `│ ❯ 1. Yes                                                                        │` of `Do you want to make this edit to <file>?`
    if line:match("^│ ❯ .+") then
      return false
    end

    if line:match("^  %-%- INSERT %-%- ") or line:match("^  %-%- INSERT MODE %-%- ") then
      return false
    end
    if line:match("^  %? for shortcuts ") or line:match("^  %-%- NORMAL MODE %-%- ") then
      return true
    end

    -- ╭──────────────────────────────────────────────────────────╮
    -- │ >                                                        │
    -- ╰──────────────────────────────────────────────────────────╯
    --                                       ⧉ In claude-code.lua
    --
    -- ╭──────────────────────────────────────────────────────────╮
    -- │ > 11111111111111111111111111111111111111111111111111111  │
    -- │   111                                                    │
    -- ╰──────────────────────────────────────────────────────────╯
    --                                         ◯ IDE disconnected
    --
    -- ╭──────────────────────────────────────────────────────────╮
    -- │ > 1                                                      │
    -- ╰──────────────────────────────────────────────────────────╯
    --                                                          ◯
    if line:match("^╭─.+─╮$") and lines[i + 1]:match("^│ > .*  │$") then
      has_input_prompt = true
    elseif
      has_input_prompt
      and line:match("^╰─.+─╯$")
      and (
        lines[i + 1]:match("^%s+◯ IDE disconnected$")
        or lines[i + 1]:match("^%s+◯$")
        or lines[i + 1]:match("^%s+⧉ In .+")
      )
    then
      -- empty mode means normal mode
      return true
    end
  end
end

---@module "lazy"
---@type LazySpec
return {
  {
    "coder/claudecode.nvim",
    dependencies = {
      "folke/snacks.nvim",
      -- -- TODO: https://github.com/coder/claudecode.nvim/pull/65
      -- ---@module "snacks"
      -- ---@type snacks.Config
      -- opts = {
      --   terminal = {
      --     win = {
      --       keys = {
      --         claude_close = {
      --           H.toggle_key,
      --           function(self)
      --             self:hide()
      --           end,
      --           mode = "t",
      --           desc = "Close",
      --         },
      --         -- copied from: https://github.com/folke/snacks.nvim/blob/bc0630e43be5699bb94dadc302c0d21615421d93/lua/snacks/terminal.lua#L49-L64
      --         term_normal = {
      --           "<esc>",
      --           function(self)
      --             local is_cc = H.is_cc(self.buf)
      --             local is_cc_norm = H.is_cc_norm(self.buf)
      --
      --             ---@diagnostic disable-next-line: inject-field
      --             self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
      --             if self.esc_timer:is_active() then
      --               self.esc_timer:stop()
      --               if is_cc_norm then
      --                 vim.api.nvim_feedkeys(vim.keycode("i"), "n", false)
      --               end
      --               vim.cmd("stopinsert")
      --             else
      --               self.esc_timer:start(
      --                 200,
      --                 0,
      --                 (not is_cc or is_cc_norm) and function() end
      --                   or vim.schedule_wrap(function()
      --                     vim.api.nvim_feedkeys(vim.keycode("<esc>"), "n", false)
      --                   end)
      --               )
      --               return (not is_cc or is_cc_norm) and "<esc>" or ""
      --             end
      --           end,
      --           mode = "t",
      --           expr = true,
      --           desc = "Double escape to normal mode",
      --         },
      --       },
      --     },
      --   },
      -- },
    },
    cmd = "ClaudeCode",
    keys = {
      -- { H.toggle_key, function() vim.cmd(H.is_cc() and "ClaudeCode" or "ClaudeCodeFocus") end, desc = "Claude Code" }, -- same behavior as `:ClaudeCodeFocus`
      {
        H.toggle_key,
        function()
          local is_visual = U.is_visual_mode()
          vim.cmd("ClaudeCodeFocus")
          if is_visual then
            -- HACK: not sure why claude code goes into its own normal mode
            vim.defer_fn(function()
              if H.is_cc_norm() then
                vim.api.nvim_feedkeys(vim.keycode("i"), "n", false)
              end
            end, 100)
          end
        end,
        desc = "Claude Code",
        mode = { "n", "x" },
      },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume (Claude)" },
      { "<leader>a.", "<cmd>ClaudeCode --continue<cr>", desc = "Continue (Claude)" },
      {
        "<leader>ab",
        function()
          vim.cmd("ClaudeCodeAdd %")
          vim.schedule(function()
            vim.cmd("ClaudeCodeFocus")
          end)
        end,
        desc = "Add Buffer (Claude)",
      },
      {
        "<leader>as",
        function()
          vim.cmd("ClaudeCodeSend")
          vim.schedule(function()
            vim.cmd("ClaudeCodeFocus")
          end)
        end,
        desc = "Send (Claude)",
        mode = "x",
      },
      { "=", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add File (Claude)", mode = { "n", "x" }, ft = "neo-tree" },
      { "<localleader>=", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add File (Claude)", ft = "oil" },
      -- { "<M-space>", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Diff (Claude)" }, -- set `Diff tool` to `terminal`
      -- { "<M-cr>", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Diff (Claude)" },
    },
    -- init = function()
    --   -- see: https://github.com/coder/claudecode.nvim/issues/52#issuecomment-2993522840
    --   vim.env.CLAUDE_CONFIG_DIR = vim.fn.expand("~/.config/claude")
    -- end,
    opts = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*:claude*",
        callback = function(ev)
          if vim.bo[ev.buf].filetype == "snacks_terminal" then
            vim.b[ev.buf].user_lualine_filename = "claude-code"
          end
        end,
      })

      vim.api.nvim_create_autocmd("TermEnter", {
        group = vim.api.nvim_create_augroup("claude_vi_mode", {}),
        pattern = "term://*:claude*",
        desc = "Enter insert mode of claude code",
        callback = vim.schedule_wrap(function()
          if H.is_cc_norm() then
            vim.api.nvim_feedkeys(vim.keycode("i"), "n", false)
          end
        end),
      })

      return {
        terminal = {
          split_width_percentage = 0.4,
        },
      }
    end,
  },

  -- TODO: https://github.com/coder/claudecode.nvim/pull/65
  {
    "qw457812/claudecode.nvim",
    branch = "feat_snacks_win_opts",
    optional = true,
    opts = {
      terminal = {
        ---@module "snacks"
        ---@type snacks.win.Config|{}
        snacks_win_opts = {
          position = "float",
          width = 0.9,
          height = 0.9,
          keys = {
            claude_close = {
              H.toggle_key,
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
                local is_cc_norm = H.is_cc_norm(self.buf)

                ---@diagnostic disable-next-line: inject-field
                self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
                if self.esc_timer:is_active() then
                  self.esc_timer:stop()
                  if is_cc_norm then
                    vim.api.nvim_feedkeys(vim.keycode("i"), "n", false)
                  end
                  vim.cmd("stopinsert")
                else
                  self.esc_timer:start(200, 0, is_cc_norm and function() end or vim.schedule_wrap(function()
                    vim.api.nvim_feedkeys(vim.keycode("<esc>"), "n", false)
                  end))
                  return is_cc_norm and "<esc>" or ""
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
}
