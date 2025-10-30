---@class util.git
local M = {}

---@class user.util.git.diff.term.Opts: snacks.terminal.Opts
---@field args? string[] additional arguments to pass to `git`
---@field cmd_args? string[] additional arguments to pass to the `git <cmd>``

---@param opts? user.util.git.diff.term.Opts
---@return snacks.terminal?
function M.diff_term(opts)
  ---@type user.util.git.diff.term.Opts
  opts = vim.tbl_deep_extend("force", { args = {}, cmd_args = {} }, opts or {})

  local git_root = Snacks.git.get_root(opts.cwd)
  if not git_root then
    Snacks.notify.error("Not a git repo")
    return
  end

  local cmd = { "git", "-c", "delta.paging=never" }
  vim.list_extend(cmd, vim.g.user_is_termux and {} or { "-c", "delta.line-numbers=true" })
  vim.list_extend(cmd, opts.args)
  table.insert(cmd, "diff")
  vim.list_extend(cmd, opts.cmd_args)

  ---@type user.util.git.diff.term.Opts
  opts = vim.tbl_deep_extend("force", {
    cwd = git_root,
    interactive = false, -- normal mode in favor of copying
    win = {
      height = U.snacks.win.fullscreen_height,
      width = 0,
      b = {
        user_lualine_filename = table
          .concat(vim.list_extend({ "git", "diff" }, opts.cmd_args), " ")
          :gsub(" %-%- .*$", ""),
      },
    },
  }, opts)

  local on_close = opts.win.on_close
  opts.win.on_close = function(win)
    -- fully close on hide to make it one-time
    win:close()
    if on_close then
      on_close(win)
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

  terminal:on("TermClose", function()
    if type(vim.v.event) == "table" and vim.v.event.status ~= 0 then
      Snacks.notify.error(("Command failed:\n- cmd: `%s`"):format(table.concat(cmd, " ")))
      terminal:close()
    else
      vim.defer_fn(function()
        if terminal:line(2) == "[Process exited 0]" then
          Snacks.notify.warn(("No changes found:\n- cmd: `%s`"):format(table.concat(cmd, " ")))
          terminal:close()
        end
      end, 20)
    end
  end, { buf = true })

  return terminal
end

return M
