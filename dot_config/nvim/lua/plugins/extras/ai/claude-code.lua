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
    dependencies = "folke/snacks.nvim",
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
          ---@module "snacks"
          ---@type snacks.win.Config|{}
          snacks_win_opts = {
            position = "float",
            -- TODO: duplicated code with `gemini-cli.lua`
            -- fullscreen on termux
            height = vim.g.user_is_termux
                ---@param self snacks.win
                and function(self)
                  local bottom = (vim.o.cmdheight + (vim.o.laststatus == 3 and 1 or 0)) or 0
                  local top = (vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1))
                      and 1
                    or 0
                  local border = self:border_size()
                  return vim.o.lines - top - bottom - border.top - border.bottom
                end
              or 0.9,
            width = vim.g.user_is_termux and 0 or 0.9,
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
      }
    end,
  },
}
