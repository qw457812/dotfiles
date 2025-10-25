---@class util.terminal
---@overload fun(cmd?: string|string[], opts?: snacks.terminal.Opts): snacks.terminal
local M = setmetatable({}, {
  ---@param t util.terminal
  __call = function(t, ...)
    return t.toggle(...)
  end,
})

-- TODO: refactor
---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
---@return snacks.win
function M.toggle(cmd, opts)
  if vim.bo.filetype == "snacks_terminal" then
    local win = vim.api.nvim_get_current_win()
    ---@param t snacks.win
    local terminal = vim.tbl_filter(function(t)
      return t.win == win
    end, Snacks.terminal.list())[1]
    vim.cmd("close")
    return terminal
  end
  return Snacks.terminal(cmd, opts)
end

--- pager
--- see `:h terminal-scrollback-pager`
function M.colorize()
  Snacks.terminal.colorize()

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  vim.b[buf].minianimate_disable = true
  vim.b[buf].miniindentscope_disable = true
  -- vim.b[buf].snacks_scroll = false
  vim.wo[win].sidescrolloff = 0

  vim.keymap.set({ "n", "x" }, "u", "<C-u>", { silent = true, buffer = buf, desc = "Scroll Up" })
  vim.keymap.set({ "n", "x" }, "d", "<C-d>", { silent = true, buffer = buf, nowait = true, desc = "Scroll Down" })

  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyVimKeymaps",
    once = true,
    callback = function()
      local orig_dd_keymap = vim.fn.maparg("dd", "n", false, true) --[[@as table<string,any>]]
      -- stylua: ignore
      if not vim.tbl_isempty(orig_dd_keymap) then
        vim.keymap.del("n", "dd")
        vim.api.nvim_create_autocmd("BufEnter", { buffer = buf, callback = function() pcall(vim.keymap.del, "n", "dd") end })
        vim.api.nvim_create_autocmd("BufLeave", { buffer = buf, callback = function() vim.fn.mapset("n", false, orig_dd_keymap) end })
      end
    end,
  })

  if vim.g.user_close_key then
    vim.keymap.set("x", vim.g.user_close_key, function()
      vim.cmd.normal({ "y", bang = true })
      vim.cmd.normal(vim.keycode(vim.g.user_close_key))
    end, { buffer = buf, desc = "Yank and Quit" })
  end
end

--- set in kitty.conf:
---
--- ```
--- scrollback_pager nvim -c "lua require('util.terminal').kitty_scrollback_pager(INPUT_LINE_NUMBER, CURSOR_LINE, CURSOR_COLUMN)"
--- ```
---@param input_line_number integer
---@param cursor_line integer
---@param cursor_column integer
function M.kitty_scrollback_pager(input_line_number, cursor_line, cursor_column)
  M.colorize()

  U.on_very_very_lazy(function()
    vim.fn.winrestview({
      topline = input_line_number,
      lnum = input_line_number + cursor_line - 1,
      -- col = cursor_column, -- not working well
      col = 0,
    })
    -- https://github.com/ray-x/nvim/blob/5b4905384bbb6b34c988ed3b115b6583972e2f09/lua/core/kitty_page.lua#L29-L30
    vim.cmd("normal! " .. (cursor_column - 1) .. "l")
  end, 100)
end

return M
