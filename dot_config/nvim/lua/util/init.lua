---@class util
---@field color util.color
---@field explorer util.explorer
---@field java util.java
---@field keymap util.keymap
---@field lualine util.lualine
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

---@param fn fun()
function M.on_very_very_lazy(fn)
  LazyVim.on_very_lazy(function()
    vim.defer_fn(function()
      fn()
    end, 200)
  end)
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

    local is_snacks_explorer = vim.iter(Snacks.picker.get({ source = "explorer" })):any(function(picker)
      return vim.iter(picker.layout.wins or {}):any(function(_, w)
        return w.win == win
      end)
    end)

    if is_tsc or is_snacks_explorer or vim.list_contains({ "snacks_dashboard", "layers_help" }, ft) then
      return false
    end
  end

  return true
end

---@param win? integer
function M.too_narrow(win)
  return vim.o.columns < 120 or vim.api.nvim_win_get_width(win or 0) < 120
end

-- snacks bigfile
---@param buf? integer
function M.is_bigfile(buf)
  buf = buf or 0
  return vim.bo[buf].filetype == "bigfile" or vim.b[buf].bigfile
end

-- see: https://github.com/folke/edgy.nvim/blob/e94e851f9dc296c2949d4c524b1be7de2340306e/lua/edgy/editor.lua#L80-L109
---@param win? integer
---@return boolean
function M.is_edgy_win(win)
  if not package.loaded["edgy"] then
    return false
  end
  win = win or 0
  win = win == 0 and vim.api.nvim_get_current_win() or win
  return vim.iter(require("edgy.config").layout):any(function(_, edgebar)
    return vim.iter(edgebar.wins):any(function(w)
      return w.win == win
    end)
  end)
end

---@param mode? string
---@return boolean, string
function M.is_visual_mode(mode)
  mode = mode or vim.fn.mode()
  return vim.list_contains({ "v", "V", vim.keycode("<C-v>") }, mode:sub(1, 1)), mode
end

---@param mode? string
function M.stop_visual_mode(mode)
  mode = mode or vim.fn.mode()
  if M.is_visual_mode(mode) then
    vim.cmd("normal! " .. mode:sub(1, 1))
  end
end

---@alias GetVisualSelectionOpts {strict?: boolean, stop_visual_mode?: boolean}

--- Get visually selected lines.
--- https://github.com/ibhagwan/fzf-lua/blob/f39de2d77755e90a7a80989b007f0bf2ca13b0dd/lua/fzf-lua/utils.lua#L770
--- https://github.com/MagicDuck/grug-far.nvim/blob/308e357be687197605cf19222f843fbb331f50f5/lua/grug-far.lua#L448
--- https://github.com/olimorris/codecompanion.nvim/blob/84a8e8962e9ae20b8357d813dee1ea44a8079605/lua/codecompanion/utils/context.lua#L34-L93
---@param opts? GetVisualSelectionOpts
---@return string[]?
function M.get_visual_selection_lines(opts)
  opts = opts or {}
  local mode = vim.fn.mode()
  local lines
  if M.is_visual_mode(mode) then
    lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
    if opts.stop_visual_mode ~= false then
      M.stop_visual_mode(mode)
    end
  elseif opts.strict ~= true then
    lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })
  end
  return lines
end

--- Get visually selected contents.
---@param opts? GetVisualSelectionOpts
---@return string?
function M.get_visual_selection(opts)
  opts = opts or {}
  local selection
  -- prefer register workaround to trigger `vim.hl.on_yank()`
  if M.is_visual_mode() then
    local cache_z_reg = vim.fn.getreginfo("z")
    vim.cmd.normal('"zy')
    if opts.stop_visual_mode == false then
      vim.cmd.normal("gv")
    end
    selection = vim.fn.getreg("z")
    vim.fn.setreg("z", cache_z_reg)
  else
    local lines = M.get_visual_selection_lines(opts)
    selection = lines and table.concat(lines, "\n") or nil
  end
  return selection
end

---@param url string
function M.open_in_browser(url)
  -- do not open github url via GitHub app on termux
  -- https://www.reddit.com/r/termux/comments/gsafc0/comment/fs44i6b/
  vim.ui.open(url, vim.g.user_is_termux and url:match("^https://github%.com/(.+)$") and {
    cmd = {
      "am",
      "start",
      "-n",
      "com.kiwibrowser.browser/com.google.android.apps.chrome.Main",
      "-d",
    },
  } or nil)
end

--- copied from: https://github.com/nvim-lua/plenary.nvim/blob/f031bef84630f556c2fb81215826ea419d81f4e9/lua/plenary/curl.lua#L44-L55
--- https://github.com/mistweaverco/kulala.nvim/blob/1c4156b8204137ff683d7c61b94218ca1cfbf801/lua/kulala/utils/string.lua#L22-L30
---@param str string
function M.url_encode(str)
  str = str:gsub("\r?\n", "\r\n")
  str = str:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", c:byte())
  end)
  return str:gsub(" ", "+")
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
  local b = vim.api.nvim_win_get_buf(win_id or 0)
  local try_mimic_buf_reuse = (vim.fn.bufname(b) == "" and vim.bo[b].buftype ~= "quickfix" and not vim.bo[b].modified)
    and (#vim.fn.win_findbuf(b) == 1 and vim.deep_equal(vim.fn.getbufline(b, 1, "$"), { "" }))
  local buf_id = vim.fn.bufadd(vim.fn.fnamemodify(path, ":."))
  -- Showing in window also loads. Use `pcall` to not error with swap messages.
  pcall(vim.api.nvim_win_set_buf, win_id or 0, buf_id)
  vim.bo[buf_id].buflisted = true
  if try_mimic_buf_reuse then
    pcall(vim.api.nvim_buf_delete, b, { unload = false })
  end
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
local debounce_timers = {}

--- alternative: https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/2ebe591cff06018e265263e71e1dbc4c5aa8281e/lua/CopilotChat/utils.lua#L157
---@param id string
---@param ms integer
---@param fn function
function M.debounce(id, ms, fn)
  debounce_timers[id] = debounce_timers[id] or assert(vim.uv.new_timer())
  local timer = debounce_timers[id]
  timer:start(ms, 0, function()
    timer:stop()
    vim.schedule(fn)
  end)
end

return M
