---@class util
---@field color util.color
---@field explorer util.explorer
---@field java util.java
---@field keymap util.keymap
---@field lualine util.lualine
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
    -- return t[k] -- https://github.com/folke/snacks.nvim/commit/d0794dc
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
---@param opts? {zen?: boolean, misc?: boolean} default true
---      - zen: whether to treat zen-mode as floating window
---      - misc: whether to treat nvim-treesitter-context, snacks_dashboard terminal sections, layers.nvim help as floating windows
---@return boolean
function M.is_floating_win(win, opts)
  win = win or 0

  if vim.api.nvim_win_get_config(win).relative == "" then
    return false
  elseif not opts then
    return true
  end

  win = win == 0 and vim.api.nvim_get_current_win() or win
  opts = vim.tbl_deep_extend("keep", opts, { zen = true, misc = true })

  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype

  -- snacks zen or zen-mode.nvim
  if not opts.zen then
    if
      Snacks.toggle.get("zen"):get()
      and (
        win == Snacks.zen.win.win
        or win == vim.tbl_get(Snacks.zen.win, "backdrop", "win")
        or ft == "snacks_zen_zoom_indicator"
      )
    then
      return false
    end
    if package.loaded["zen-mode"] then
      local zen_mode = require("zen-mode.view")
      if zen_mode.is_open() and (win == zen_mode.win or win == zen_mode.bg_win) then
        return false
      end
    end
  end

  if not opts.misc then
    -- see: https://github.com/nvim-treesitter/nvim-treesitter-context/blob/a2a334900d3643de585ac5c6140b03403454124f/lua/treesitter-context/render.lua#L56
    local is_tsc = package.loaded["treesitter-context"]
      and (vim.w[win].treesitter_context or vim.w[win].treesitter_context_line_number)

    local is_snacks_explorer = (function()
      local picker = Snacks.picker.get({ source = "explorer" })[1]
      if not picker then
        return false
      end
      for _, w in pairs(picker.layout.wins or {}) do
        if w.win == win then
          return true
        end
      end
      return false
    end)()

    if is_tsc or is_snacks_explorer or vim.list_contains({ "snacks_dashboard", "layers_help" }, ft) then
      return false
    end
  end

  return true
end

function M.stop_visual_mode()
  local mode = vim.fn.mode():sub(1, 1) ---@type string
  if vim.tbl_contains({ "v", "V", vim.keycode("<C-v>") }, mode) then
    vim.cmd("normal! " .. mode)
  end
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

--- https://github.com/echasnovski/mini.files/commit/2756117
--- vim.cmd.edit(path)
---@param path
---@param win_id?
---@return integer?
function M.edit(path, win_id)
  if type(path) ~= "string" then
    return
  end
  local buf_id = vim.fn.bufadd(vim.fn.fnamemodify(path, ":."))
  -- Showing in window also loads. Use `pcall` to not error with swap messages.
  pcall(vim.api.nvim_win_set_buf, win_id or 0, buf_id)
  vim.bo[buf_id].buflisted = true
  return buf_id
end

--- Insert one or more values into a list like table and maintain that you
--- do not insert non-unique values (THIS MODIFIES `dst`)
---@param dst any[]|nil The list like table that you want to insert into
---@param src any|any[] Either a list like table of values to be inserted or a single value to be inserted
---@return any[] # The modified list like table
function M.list_insert_unique(dst, src)
  dst = dst or {}
  assert(vim.islist(dst), "Provided table is not a list like table")
  src = vim.islist(src) and src or { src }
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
  local timer = assert(vim.uv.new_timer())
  return function(...)
    local argv = vim.F.pack_len(...)
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(vim.F.unpack_len(argv))
    end)
  end
end

---@type table<string, uv.uv_timer_t>
local timers = {}

--- alternative: https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/2ebe591cff06018e265263e71e1dbc4c5aa8281e/lua/CopilotChat/utils.lua#L157
---@param id string
---@param ms integer
---@param fn function
function M.debounce(id, ms, fn)
  timers[id] = timers[id] or assert(vim.uv.new_timer())
  local timer = timers[id]
  timer:start(ms, 0, function()
    timer:stop()
    vim.schedule(fn)
  end)
end

return M
