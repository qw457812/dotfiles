---@class util.terminal
---@overload fun(cmd?: string|string[], opts?: snacks.terminal.Opts): snacks.terminal
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.toggle(...)
  end,
})

---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
function M.toggle(cmd, opts)
  if vim.bo.filetype == "snacks_terminal" then
    vim.cmd("close")
    return
  end

  Snacks.terminal(cmd, opts)
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
      vim.cmd.normal("y")
      vim.api.nvim_feedkeys(vim.keycode(vim.g.user_close_key), "m", false)
    end, { silent = true, buffer = buf, desc = "Yank then Quit" })
  end
end

return M
