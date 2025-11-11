---@class util.git
local M = {}

---@class user.util.git.diff.term.Opts: snacks.terminal.Opts
---@field args? string[] additional arguments to pass to `git`
---@field cmd_args? string[] additional arguments to pass to the `git <cmd>``
---@field staged? boolean
---@field ignore_space? boolean
---@field on_diff? fun(has_diff:boolean) Callback for when changes are found, after closing the window

---use `opts.staged = true` instead of `opts.cmd_args = { "--staged" }` or `opts.cmd_args = { "--cached" }`
---ref: https://github.com/folke/lazy.nvim/blob/a32e307981519a25dd3f05a33a6b7eea709f0fdc/lua/lazy/view/diff.lua#L49-L61
---@param opts? user.util.git.diff.term.Opts
---@return snacks.terminal?
function M.diff_term(opts)
  opts = opts or {}
  local git_root = Snacks.git.get_root(opts.cwd)
  if not git_root then
    Snacks.notify.error("Not a git repo")
    return
  end

  ---@type user.util.git.diff.term.Opts
  opts = vim.tbl_deep_extend("force", {
    args = {},
    cmd_args = {},
    cwd = git_root,
    interactive = false, -- normal mode in favor of copying
    -- env = { PAGER = "cat" }, -- alternative to `-c delta.paging=never`
    win = {
      height = U.snacks.win.fullscreen_height,
      width = 0,
      b = {
        user_lualine_filename = "diff",
      },
    },
  } --[[@as user.util.git.diff.term.Opts]], opts)

  local cmd = { "git", "-c", "delta.paging=never" }
  vim.list_extend(cmd, vim.g.user_is_termux and {} or { "-c", "delta.line-numbers=true" })
  vim.list_extend(cmd, opts.args)
  table.insert(cmd, "diff")
  if opts.ignore_space then
    vim.list_extend(cmd, { "--ignore-all-space", "--ignore-blank-lines", "--ignore-cr-at-eol" })
  end
  if opts.staged then
    table.insert(cmd, "--cached")
  elseif opts.staged == nil then
    table.insert(cmd, "HEAD") -- staged + unstaged
  end
  vim.list_extend(cmd, opts.cmd_args)

  local on_close = opts.win.on_close
  local has_diff = true
  opts.win.on_close = function(win)
    win:close() -- fully close on hide to make it one-time
    if on_close then
      on_close(win)
    end
    if opts.on_diff then
      opts.on_diff(has_diff)
    end
  end

  local on_win = opts.win.on_win
  opts.win.on_win = function(win)
    if not win:win_valid() then
      return
    end
    vim.wo[win.win].scrolloff = math.floor((vim.api.nvim_win_get_height(win.win) - 1) / 2)
    vim.api.nvim_win_call(
      win.win,
      vim.schedule_wrap(function()
        vim.cmd.normal({ "M", bang = true })
      end)
    )
    if on_win then
      on_win(win)
    end
  end

  local terminal = Snacks.terminal(cmd, opts)

  terminal:on("TermEnter", function()
    vim.cmd.stopinsert()
  end, { buf = true })

  local function on_error()
    has_diff = false
    terminal:close()
  end

  terminal:on("TermClose", function()
    if type(vim.v.event) == "table" and vim.v.event.status ~= 0 then
      Snacks.notify.error(("Command failed:\n- cmd: `%s`"):format(table.concat(cmd, " ")))
      on_error()
    else
      -- -- close terminal if no changes found (alternative: vim.defer_fn)
      -- local line2 ---@type string?
      -- -- local start = vim.uv.hrtime()
      -- -- local polls = 0
      -- vim.wait(30, function()
      --   -- polls = polls + 1
      --   line2 = terminal:line(2)
      --   return line2 ~= ""
      -- end, 5)
      -- -- local elapsed = (vim.uv.hrtime() - start) / 1e6
      -- -- Snacks.debug.inspect({ line2 = line2, polls = polls, elapsed = string.format("%.2fms", elapsed) })
      -- if line2 == "[Process exited 0]" then
      --   Snacks.notify.warn(("No changes found:\n- cmd: `%s`"):format(table.concat(cmd, " ")))
      --   on_error()
      -- end

      if terminal.buf then
        U.terminal.hide_process_exited(terminal.buf, function(lnum)
          -- close terminal if no changes found
          if lnum == 2 then
            Snacks.notify.warn(("No changes found:\n- cmd: `%s`"):format(table.concat(cmd, " ")))
            on_error()
          end
        end)
      end
    end
  end, { buf = true })

  return terminal
end

return M
