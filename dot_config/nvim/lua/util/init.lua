---@class util
---@field path util.path
local M = {}

setmetatable(M, {
  __index = function(t, k)
    t[k] = require("util." .. k)
    return t[k]
  end,
})

--- `lua/plugins/extras`
---@param extra string
function M.has_user_extra(extra)
  local Config = require("lazyvim.config")
  local modname = "plugins.extras." .. extra
  return vim.tbl_contains(require("lazy.core.config").spec.modules, modname)
    or vim.tbl_contains(Config.json.data.extras, modname)
end

--- Wrapper around vim.keymap.set that will set `silent` to true by default.
--- https://github.com/folke/dot/blob/5df77fa64728a333f4d58e35d3ca5d8590c4f928/nvim/lua/config/options.lua#L22
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? vim.keymap.set.Opts
function M.keymap(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

--- Get visually selected lines.
--- alternative: https://github.com/ibhagwan/fzf-lua/blob/f39de2d77755e90a7a80989b007f0bf2ca13b0dd/lua/fzf-lua/utils.lua#L770
---@param stop_visual_mode? boolean
function M.get_visual_selection(stop_visual_mode)
  local mode = vim.fn.mode(true)
  -- VISUAL 'v', VISUAL LINE 'V' and VISUAL BLOCK '\22'
  local is_visual = mode == "v" or mode == "V" or mode == "\22"
  assert(is_visual, "Not in Visual mode")

  local cache_z_reg = vim.fn.getreginfo("z")
  vim.cmd.normal('"zy')
  if stop_visual_mode == false then
    vim.cmd.normal("gv")
  end
  local selection = vim.fn.getreg("z")
  vim.fn.setreg("z", cache_z_reg)
  return selection
end

--- Insert one or more values into a list like table and maintain that you do not insert non-unique values (THIS MODIFIES `dst`)
--- copied from: https://github.com/AstroNvim/astrocore/blob/cf5823e2b59aa9666445e3f3531296ad8f417b7c/lua/astrocore/init.lua#L50
---@param dst any[]|nil The list like table that you want to insert into
---@param src any[] Values to be inserted
---@return any[] # The modified list like table
function M.list_insert_unique(dst, src)
  if not dst then
    dst = {}
  end
  assert(vim.islist(dst), "Provided table is not a list like table")
  local added = {}
  for _, val in ipairs(dst) do
    added[val] = true
  end
  for _, val in ipairs(src) do
    if not added[val] then
      table.insert(dst, val)
      added[val] = true
    end
  end
  return dst
end

return M
