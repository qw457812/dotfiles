---@class util
---@field color util.color
---@field explorer util.explorer
---@field git util.git
---@field java util.java
---@field keymap util.keymap
---@field lsp util.lsp
---@field lualine util.lualine
---@field path util.path
---@field rime_ls util.rime_ls
---@field snacks util.snacks
---@field sql util.sql
---@field telescope util.telescope
---@field terminal util.terminal
---@field toggle util.toggle
local M = {}

setmetatable(M, {
  ---@param t util
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
---@param timeout? integer
function M.on_very_very_lazy(fn, timeout)
  timeout = timeout or 200
  LazyVim.on_very_lazy(function()
    vim.defer_fn(fn, timeout)
  end)
end

---@param win? integer default 0
---@param opts? {zen?: boolean, notify?: boolean, misc?: boolean} default true
---      - zen: whether to treat zen-mode as floating window
---      - notify: whether to treat snacks_notif, notify, noice as floating window
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
  opts = vim.tbl_deep_extend("keep", opts, { zen = true, notify = true, misc = true })

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

  if not opts.notify and vim.list_contains({ "snacks_notif", "notify", "noice" }, ft) then
    return false
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

---https://github.com/folke/snacks.nvim/blob/ce67fa9e31467590c750e203e27d3e6df293f2ad/lua/snacks/picker/core/frecency.lua#L162-L168
---https://github.com/folke/sidekick.nvim/blob/d570e1f83bf2a19e6c1fad5de9b1b07beb54b67d/lua/sidekick/cli/context/location.lua#L71-L76
---@param opts? {buf?: integer, buflisted?: boolean}
---@return boolean
---@return string?
function M.is_file(opts)
  opts = opts or {}
  local buf = opts.buf or 0
  if
    not (
      vim.api.nvim_buf_is_valid(buf)
      and (opts.buflisted == false or vim.bo[buf].buflisted)
      and vim.list_contains({ "", "help" }, vim.bo[buf].buftype)
    )
  then
    return false
  end
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" or not vim.uv.fs_stat(file) then
    return false
  end
  return true, file
end

-- snacks bigfile
---@param buf? integer
function M.is_bigfile(buf)
  buf = buf or 0
  return vim.bo[buf].filetype == "bigfile" or vim.b[buf].bigfile
end

---@return boolean
function M.too_narrow()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local is_explorer = vim.list_contains({ "neo-tree", "snacks_layout_box" }, vim.bo[buf].filetype)
    if not M.is_floating_win(win) and not is_explorer and vim.api.nvim_win_get_width(win) < 120 then
      return true
    end
  end
  return false
end

---@return boolean
function M.too_wide()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local is_explorer = vim.list_contains({ "neo-tree", "snacks_layout_box" }, vim.bo[buf].filetype)
    if
      not M.is_floating_win(win)
      and not is_explorer
      and vim.api.nvim_win_get_width(win) - vim.g.user_explorer_width < 120
    then
      return false
    end
  end
  return true
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
--- https://github.com/folke/snacks.nvim/blob/df018edfdbc5df832b46b9bdc9eafb1d69ea460b/lua/snacks/picker/core/list.lua#L383-L384
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
    vim.cmd.normal({ '"zy', bang = true })
    if opts.stop_visual_mode == false then
      vim.cmd.normal({ "gv", bang = true })
    end
    selection = vim.fn.getreg("z")
    vim.fn.setreg("z", cache_z_reg)
  else
    local lines = M.get_visual_selection_lines(opts)
    selection = lines and table.concat(lines, "\n") or nil
  end
  return selection
end

-- if vim.g.user_is_termux and vim.fn.executable("am") == 1 then
--   ---@param path string
--   ---@param opt? { cmd?: string[] }
--   vim.ui.open = U.patch_func(vim.ui.open, function(orig, path, opt)
--     opt = opt or {}
--     if not opt.cmd and path:match("^https://github%.com/.+") then
--       -- https://www.reddit.com/r/termux/comments/gsafc0/comment/fs44i6b/
--       opt.cmd = { "am", "start", "-n", "com.kiwibrowser.browser/com.google.android.apps.chrome.Main", "-d" }
--     end
--     return orig(path, opt)
--   end)
-- end
---@param url string
function M.open_in_browser(url)
  -- do not open github/reddit url via GitHub/Reddit app on termux
  if
    vim.g.user_is_termux
    and vim.fn.executable("am") == 1
    and (url:match("^https://github%.com/.+") or url:match("^https://www%.reddit%.com"))
  then
    -- "com.kiwibrowser.browser"
    -- "com.microsoft.emmx.canary"
    local browser = "org.cromite.cromite"
    vim.system({
      "am",
      "start",
      "-a",
      "android.intent.action.VIEW",
      "-d",
      url,
      browser,
    }, { text = true, detach = true })
  else
    vim.ui.open(url)
  end
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

--- https://github.com/nvim-mini/mini.files/commit/2756117
--- vim.cmd.edit(path)
---@param path string
---@param win_id? integer
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

---@param text string
---@param width number
---@param direction? -1 | 1
function M.truncate(text, width, direction)
  if width <= 1 then
    return width == 1 and "…" or ""
  end
  local tw = vim.api.nvim_strwidth(text)
  if tw > width then
    return direction == -1 and "…" .. vim.fn.strcharpart(text, tw - width + 1, width - 1)
      or vim.fn.strcharpart(text, 0, width - 1) .. "…"
  end
  return text
end

---@param buflisted? boolean
---@return number? buf
---@return string? path
---@return string? root
function M.last_file(buflisted)
  local buf = vim.api.nvim_get_current_buf()
  local _, file = U.is_file({ buf = buf, buflisted = buflisted })
  if file then
    return buf, file, LazyVim.root.get({ normalize = true, buf = buf })
  end

  local last_file = vim.g.user_last_file
  if last_file then
    return last_file.buf, last_file.path, last_file.root
  end
end

------@param prompt string
------@param fn fun(yes: boolean)
---function M.confirm(prompt, fn)
---  local ok, choice = pcall(vim.fn.confirm, prompt, "&Yes\n&No")
---  if not ok then
---    return
---  end
---  if choice == 1 then -- Yes
---    fn(true)
---  elseif choice == 0 or choice == 2 then -- 0 for <Esc> and 2 for No
---    fn(false)
---  end
---end
---ref: https://github.com/folke/snacks.nvim/blob/907679381ba5ed36a24b0176930e3ceb97ca4755/lua/snacks/picker/util/init.lua#L76-L93
---@param prompt string
---@param fn fun(yes: boolean)
function M.confirm(prompt, fn)
  Snacks.picker.select({ "No", "Yes" }, {
    prompt = prompt,
    snacks = {
      layout = {
        layout = {
          max_width = 60,
        },
      },
    },
  }, function(_, idx)
    fn(idx == 2)
  end)
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

--- alternative:
--- - https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/2ebe591cff06018e265263e71e1dbc4c5aa8281e/lua/CopilotChat/utils.lua#L157
--- - https://github.com/yetone/avante.nvim/commit/76fe3f6
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
