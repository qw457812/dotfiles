---@class util.terminal
---@overload fun(cmd?: string|string[], opts?: snacks.terminal.Opts, hide_key?: string): snacks.terminal
local M = setmetatable({}, {
  ---@param t util.terminal
  __call = function(t, ...)
    return t.toggle(...)
  end,
})

---@class vim.var_accessor
---https://github.com/folke/snacks.nvim/blob/8c501965beff9a741b29eea53c7f876b039bddea/lua/snacks/terminal.lua#L111
---@field snacks_terminal? { cmd?: string | string[], id: integer, cwd?: string, env?: table<string, string> }

---@param cmd? string | string[]
---@param opts? snacks.terminal.Opts
---@param hide_key? string
---@return snacks.win
function M.toggle(cmd, opts, hide_key)
  opts = opts or {}
  local win = vim.api.nvim_get_current_win()

  if hide_key then
    opts = vim.tbl_deep_extend("force", {
      win = { keys = { ["hide_" .. hide_key] = { hide_key, "hide", desc = "Hide Terminal", mode = "t" } } },
    }, opts)
  end

  if vim.tbl_get(opts, "win", "position") == "float" then
    opts = vim.tbl_deep_extend("force", {
      win = {
        height = vim.g.user_is_termux and U.snacks.win.fullscreen_height or nil,
        width = vim.g.user_is_termux and 0 or nil,
      },
      -- try `<c-/>` -> `<c-/>` -> `<c-space>` in home dir (root and cwd are the same), without this, then <c-space> will open a bottom terminal
      -- see: https://github.com/folke/snacks.nvim/blob/8c501965beff9a741b29eea53c7f876b039bddea/lua/snacks/terminal.lua#L173-L184
      env = { __NVIM_SNACKS_TERMINAL_POSITION = "float" },
    }, opts)
  end

  -- HACK: re-open the explorer to do something like `opts.options.offsets` of bufferline.nvim
  local on_win = opts.win and opts.win.on_win
  ---@param self snacks.terminal
  opts.win.on_win = function(self)
    if not self:is_floating() and U.explorer.is_visible() then
      U.explorer.close()
      vim.schedule(function()
        U.explorer.open({ focus = false })
        -- prevent the explorer from becoming the "previous window", otherwise `<c-/>` -> `<c-/>` ends up focusing the explorer
        if vim.api.nvim_win_is_valid(win) and self:win_valid() then
          vim.api.nvim_set_current_win(win)
          vim.api.nvim_set_current_win(self.win)
        end
      end)
    end
    if on_win then
      on_win(self)
    end
  end

  local st = vim.b.snacks_terminal or {}
  if
    vim.fn.mode() == "n" -- terminal mode handled by `hide_key`
    and vim.bo.filetype == "snacks_terminal"
    -- Instead of toggling the [1](https://github.com/folke/snacks.nvim/blob/8c501965beff9a741b29eea53c7f876b039bddea/lua/snacks/terminal.lua#L182), we want to close the current terminal.
    -- Try `<c-/>` -> `<esc><esc>` -> `2<c-/>` -> `<esc><esc>` -> `<c-/>`, without this, the last `<c-/>` will close the first opened terminal instead of closing the current one.
    -- See: https://github.com/LazyVim/LazyVim/pull/6774#issuecomment-3519559573
    and vim.v.count == 0
    -- Try `<c-/>` -> `<esc><esc>` -> `<c-space>`, without this, the `<c-space>` will close the bottom terminal instead of opening a float one.
    and (vim.deep_equal(st.cmd, cmd) and st.cwd == opts.cwd and vim.deep_equal(st.env, opts.env))
  then
    ---@param t snacks.win
    local terminal = vim.tbl_filter(function(t)
      return t.win == win
    end, Snacks.terminal.list())[1]
    vim.cmd("close")
    return terminal
  else
    -- TODO: focus if terminal is already open but not focused
    return Snacks.terminal(cmd, opts)
  end
end

---Hide `[Process exited 0]`
---Copied from: https://github.com/folke/snacks.nvim/blob/5faed2f7abed7fb97aed0425b2b1b03fb6048fa9/lua/snacks/util/job.lua#L229-L254
---@param buf integer
---@param on_line? fun(lnum: integer)
function M.hide_process_exited(buf, on_line)
  local timer = assert(vim.uv.new_timer())
  local stop = function()
    return timer:is_active() and timer:stop() == 0 and timer:close()
  end
  -- local start = vim.uv.hrtime()
  -- local fires = 0
  local check = function()
    -- fires = fires + 1
    if vim.api.nvim_buf_is_valid(buf) then
      for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, true)) do
        if line:find("^%[Process exited 0%]") then
          -- local elapsed = (vim.uv.hrtime() - start) / 1e6
          -- Snacks.debug.inspect({ fires = fires, elapsed = string.format("%.2fms", elapsed) })
          vim.bo[buf].modifiable = true
          vim.api.nvim_buf_set_lines(buf, i - 1, i, true, {})
          vim.bo[buf].modifiable = false
          if on_line then
            on_line(i)
          end
          return stop()
        end
      end
    end
  end
  timer:start(30, 30, vim.schedule_wrap(check))
  vim.defer_fn(stop, 1000)
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
