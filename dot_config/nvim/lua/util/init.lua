---@class util
---@field color util.color
---@field explorer util.explorer
---@field path util.path
---@field telescope util.telescope
---@field toggle util.toggle
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
---@param lhs string|string[]
---@param rhs string|function
---@param opts? vim.keymap.set.Opts
function M.keymap(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  -- -- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/utils.lua#L17
  -- opts.unique = opts.unique ~= false

  ---@cast lhs string[]
  lhs = type(lhs) == "string" and { lhs } or lhs

  for _, l in ipairs(lhs) do
    vim.keymap.set(mode, l, rhs, opts)
  end
end

---@param win? integer default 0
---@param zenmode_as_floating? boolean default true
---@param treesitter_context_as_floating? boolean default true
---@return boolean
function M.is_floating(win, zenmode_as_floating, treesitter_context_as_floating)
  win = win or 0
  local is_float = vim.api.nvim_win_get_config(win).relative ~= ""
  if is_float and zenmode_as_floating == false and package.loaded["zen-mode"] then
    local zen_mode = require("zen-mode.view")
    if zen_mode.is_open() then
      win = win == 0 and vim.api.nvim_get_current_win() or win
      is_float = win ~= zen_mode.win and win ~= zen_mode.bg_win
    end
  end
  if is_float and treesitter_context_as_floating == false and package.loaded["treesitter-context"] then
    -- see: https://github.com/nvim-treesitter/nvim-treesitter-context/blob/a2a334900d3643de585ac5c6140b03403454124f/lua/treesitter-context/render.lua#L56
    is_float = not (vim.w[win].treesitter_context or vim.w[win].treesitter_context_line_number)
  end
  return is_float
end

--- Get visually selected lines.
--- alternative:
--- https://github.com/ibhagwan/fzf-lua/blob/f39de2d77755e90a7a80989b007f0bf2ca13b0dd/lua/fzf-lua/utils.lua#L770
--- https://github.com/MagicDuck/grug-far.nvim/blob/308e357be687197605cf19222f843fbb331f50f5/lua/grug-far.lua#L448
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

--- Merge extended options with a default table of options
--- copied from: https://github.com/AstroNvim/astrocore/blob/d687e4b66b93783dfdafee1e64d363b7706056ff/lua/astrocore/init.lua#L25
---@param default? table The default table that you want to merge into
---@param opts? table The new options that should be merged with the default table
---@return table # The merged table
function M.extend_tbl(default, opts)
  opts = opts or {}
  return default and vim.tbl_deep_extend("force", default, opts) or opts
end

--- Insert one or more values into a list like table and maintain that you do not insert non-unique values (THIS MODIFIES `dst`)
---@param dst any[]|nil The list like table that you want to insert into
---@param src any Value(s) to be inserted
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
  src = type(src) == "table" and src or { src }
  for _, val in ipairs(src) do
    if not added[val] then
      table.insert(dst, val)
      added[val] = true
    end
  end
  return dst
end

--- Monkey patch into an existing function
---
--- Example from `:h vim.paste()`
--- ```lua
--- vim.paste = require("util").patch_func(vim.paste, function(orig, lines, phase)
---   for i, line in ipairs(lines) do
---     -- Scrub ANSI color codes from paste input.
---     lines[i] = line:gsub('\27%[[0-9;mK]+', '')
---   end
---   return orig(lines, phase)
--- end)
--- ```
---@param orig? function the original function to override, if `nil` is provided then an empty function is passed
---@param override fun(orig:function, ...):... the override function
---@return function the new function with the patch applied
function M.patch_func(orig, override)
  if not orig then
    orig = function() end
  end
  return function(...)
    return override(orig, ...)
  end
end

return M
