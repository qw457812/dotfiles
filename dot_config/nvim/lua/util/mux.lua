---@class util.mux
local M = {}

M.tmux = {
  -- https://github.com/folke/zen-mode.nvim/blob/a31cf7113db34646ca320f8c2df22cf1fbfc6f2a/lua/zen-mode/plugins.lua#L96
  get_opt = function(option)
    local option_raw = vim.fn.system([[tmux show -w ]] .. option)
    if option_raw == "" then
      option_raw = vim.fn.system([[tmux show -g ]] .. option)
    end
    local opt = vim.split(vim.trim(option_raw), " ")[2]
    return opt
  end,
}

M.wezterm = {
  -- We dont use `require("wezterm").get_current_pane()` since `$WEZTERM_PANE` could be wrong
  -- when getting wezterm pane_id in tmux, use `wezterm cli list-clients --format=json` instead.
  -- See: https://github.com/wez/wezterm/issues/3413#issuecomment-1491870672
  -- https://github.com/qw457812/dotfiles/blob/5d3b7a34a77870f485b2d306f1f2fa0b13af7b09/dot_config/tmux/tmux.conf.local#L500-L508
  ---@return integer|nil
  current_pane_id = function()
    local clients = require("wezterm").list_clients()
    if not clients or #clients == 0 then
      return
    end
    table.sort(clients, function(a, b)
      return a.idle_time.nanos < b.idle_time.nanos
    end)
    return clients[1].focused_pane_id
  end,

  ---@param pane_id integer|nil
  ---@return boolean|nil
  pane_is_zoomed = function(pane_id)
    if not pane_id then
      return
    end
    local panes = require("wezterm").list_panes()
    if not panes then
      return
    end
    for _, pane in ipairs(panes) do
      if pane.pane_id == pane_id then
        return pane.is_zoomed
      end
    end
  end,
}

return M
