---@class util
---@field color util.color
---@field explorer util.explorer
---@field java util.java
---@field keymap util.keymap
---@field markdown util.markdown
---@field path util.path
---@field rime_ls util.rime_ls
---@field telescope util.telescope
---@field terminal util.terminal
---@field toggle util.toggle
local M = {}

setmetatable(M, {
  __index = function(t, k)
    t[k] = require("util." .. k)
    -- https://github.com/folke/snacks.nvim/commit/d0794dc
    -- return t[k]
    return rawget(t, k)
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

---@param win? integer default 0
---@param opts? { zen?: boolean, tsc?: boolean, dashboard?: boolean, layers?: boolean } whether to treat zen-mode, nvim-treesitter-context, snacks_dashboard terminal sections and layers help as floating windows, default true
---@return boolean
function M.is_floating_win(win, opts)
  win = win or 0
  if vim.api.nvim_win_get_config(win).relative == "" then
    return false
  end

  win = win == 0 and vim.api.nvim_get_current_win() or win
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    zen = true,
    tsc = true,
    dashboard = true,
    layers = true,
  })
  local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype

  -- snacks zen or zen-mode.nvim
  if not opts.zen then
    if Snacks.toggle.get("zen"):get() then
      if
        win == Snacks.zen.win.win
        or win == vim.tbl_get(Snacks.zen.win, "backdrop", "win")
        or ft == "snacks_zen_zoom_indicator"
      then
        return false
      end
    end
    if package.loaded["zen-mode"] then
      local zen_mode = require("zen-mode.view")
      if zen_mode.is_open() then
        if win == zen_mode.win or win == zen_mode.bg_win then
          return false
        end
      end
    end
  end

  -- nvim-treesitter-context
  -- see: https://github.com/nvim-treesitter/nvim-treesitter-context/blob/a2a334900d3643de585ac5c6140b03403454124f/lua/treesitter-context/render.lua#L56
  if
    not opts.tsc
    and package.loaded["treesitter-context"]
    and (vim.w[win].treesitter_context or vim.w[win].treesitter_context_line_number)
  then
    return false
  end

  -- snacks_dashboard terminal sections
  if not opts.dashboard and ft == "snacks_dashboard" then
    return false
  end

  -- layers.nvim help
  if not opts.layers and ft == "layers_help" then
    return false
  end

  return true
end

--- Get visually selected lines.
--- alternative:
--- https://github.com/ibhagwan/fzf-lua/blob/f39de2d77755e90a7a80989b007f0bf2ca13b0dd/lua/fzf-lua/utils.lua#L770
--- https://github.com/MagicDuck/grug-far.nvim/blob/308e357be687197605cf19222f843fbb331f50f5/lua/grug-far.lua#L448
---@param stop_visual_mode? boolean default true
function M.get_visual_selection(stop_visual_mode)
  local mode = vim.fn.mode(true)
  -- eval `vim.api.nvim_replace_termcodes("<C-v>", true, false, true)` or `vim.fn.nr2char(22)`
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

--- copied from: https://github.com/folke/noice.nvim/blob/eaed6cc9c06aa2013b5255349e4f26a6b17ab70f/lua/noice/util/init.lua#L104
---@param ms integer
---@param fn function
---@return function
function M.debounce_wrap(ms, fn)
  local timer = (vim.uv or vim.loop).new_timer()
  return function(...)
    local argv = vim.F.pack_len(...)
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(vim.F.unpack_len(argv))
    end)
  end
end

local timers = {}

--- alternative: https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/2ebe591cff06018e265263e71e1dbc4c5aa8281e/lua/CopilotChat/utils.lua#L157
---@param id string
---@param ms integer
---@param fn function
function M.debounce(id, ms, fn)
  timers[id] = timers[id] or vim.uv.new_timer()
  local timer = timers[id]
  timer:start(ms, 0, function()
    timer:stop()
    vim.schedule(fn)
  end)
end

return M
