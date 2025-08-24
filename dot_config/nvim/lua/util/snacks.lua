---@class util.snacks
local M = {}

M.win = {
  ---copied from: https://github.com/folke/snacks.nvim/blob/3ae98636aaaf8f1b2f55b264f5745ae268de532f/lua/snacks/layout.lua#L247-L258
  ---see also: https://github.com/folke/snacks.nvim/blob/3ae98636aaaf8f1b2f55b264f5745ae268de532f/lua/snacks/layout.lua#L475-L478
  ---@module "snacks"
  ---@param self snacks.win
  fullscreen_height = function(self)
    local bottom = (vim.o.cmdheight + (vim.o.laststatus == 3 and 1 or 0)) or 0
    local top = (vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)) and 1 or 0
    local border = self:border_size()
    return vim.o.lines - top - bottom - border.top - border.bottom
  end,
}

return M
