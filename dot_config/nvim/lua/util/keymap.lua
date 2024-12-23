---@class util.keymap
local M = {}

--- Wrapper around vim.keymap.set that will set `silent` to true by default.
--- https://github.com/folke/dot/blob/5df77fa64728a333f4d58e35d3ca5d8590c4f928/nvim/lua/config/options.lua#L22
---@param mode string|string[]
---@param lhs string|string[]
---@param rhs string|function
---@param opts? vim.keymap.set.Opts
function M.map(mode, lhs, rhs, opts)
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

-- Wrapper around vim.keymap.set that will
-- not create a keymap if a lazy key handler exists.
-- It will also set `silent` to true by default.
---@param mode string|string[]
---@param lhs string|string[]
---@param rhs string|function
---@param opts? vim.keymap.set.Opts
function M.safe_map(mode, lhs, rhs, opts)
  ---@cast lhs string[]
  lhs = type(lhs) == "string" and { lhs } or lhs

  for _, l in ipairs(lhs) do
    LazyVim.safe_keymap_set(mode, l, rhs, opts)
  end
end

---@param modes string|string[]
---@param lhs string|string[]
---@param opts? vim.keymap.del.Opts
function M.del(modes, lhs, opts)
  ---@cast lhs string[]
  lhs = type(lhs) == "string" and { lhs } or lhs

  for _, l in ipairs(lhs) do
    vim.keymap.del(modes, l, opts)
  end
end

-- copied from: https://github.com/echasnovski/mini.nvim/blob/ad46fda7862153107124f95d4ea0e510eafc1dd8/lua/mini/basics.lua#L558
local cache_empty_line
---Add empty lines before and after cursor line supporting dot-repeat
---@param put_above boolean
---@return string
function M.put_empty_line(put_above)
  -- This has a typical workflow for enabling dot-repeat:
  -- - On first call it sets `operatorfunc`, caches data, and calls
  --   `operatorfunc` on current cursor position.
  -- - On second call it performs task: puts `v:count1` empty lines
  --   above/below current line.
  if type(put_above) == "boolean" then
    vim.o.operatorfunc = "v:lua.require'util.keymap'.put_empty_line"
    cache_empty_line = { put_above = put_above }
    return "g@l"
  end
  local target_line = vim.fn.line(".") - (cache_empty_line.put_above and 1 or 0)
  vim.fn.append(target_line, vim.fn["repeat"]({ "" }, vim.v.count1))
end

-- https://github.com/folke/flash.nvim/blob/34c7be146a91fec3555c33fe89c7d643f6ef5cf1/lua/flash/jump.lua#L204
-- https://github.com/folke/snacks.nvim/blob/6b98aa11d31227081f780d6321ea7dfd97f1da59/lua/snacks/words.lua#L115
function M.foldopen_l()
  local count1 = vim.v.count1
  local first_folded_line = vim.fn.foldclosed(vim.fn.line("."))
  if first_folded_line ~= -1 then
    vim.api.nvim_win_set_cursor(0, { first_folded_line, 0 })
    vim.cmd.normal({ "zv", bang = true })
  end
  vim.cmd("normal! " .. count1 .. "l")
end

---https://github.com/megalithic/dotfiles/blob/fce3172e3cb1389de22bf97ccbf29805c2262525/config/nvim/lua/mega/mappings.lua#L143
---@param opts? {close?: function|false, popups?: boolean, esc?: boolean}
---@return boolean
function M.clear_ui_esc(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    close = function()
      -- local ft = vim.bo.filetype
      -- if ft == "oil" then
      --   require("oil").close()
      -- elseif ft == "minifiles" then
      --   require("mini.files").close()
      -- else
      --   vim.api.nvim_win_close(0, false)
      -- end

      vim.api.nvim_feedkeys(vim.keycode(vim.g.user_close_key), "m", false)
    end,
    popups = true,
    esc = true,
  })

  -- -- TODO: always true
  -- local function has_notif()
  --   return not vim.tbl_isempty(vim.tbl_filter(function(b)
  --     return vim.api.nvim_buf_is_valid(b)
  --       and vim.tbl_contains({ "snacks_notif", "notify", "noice" }, vim.bo[b].filetype)
  --   end, vim.api.nvim_list_bufs()))
  -- end

  local function dismiss_notif()
    if package.loaded["noice"] then
      require("noice").cmd("dismiss") -- including mini view like lsp progress (floating windows)
    end
  end

  local something_done = false
  local is_cmdwin = vim.fn.getcmdwintype() ~= ""
  dismiss_notif()

  if
    vim.v.hlsearch == 1 or vim.snippet.active()
    -- or has_notif()
  then
    -- dismiss_notif()
    vim.cmd("nohlsearch")
    if package.loaded["scrollbar"] then
      require("scrollbar.handlers.search").nohlsearch() -- nvim-scrollbar & nvim-hlslens
    end
    vim.snippet.stop()
    something_done = true
  elseif opts.close then
    if U.is_floating_win(0, { zen = false }) then
      opts.close()
      something_done = true
    elseif opts.popups and not is_cmdwin then
      -- close all floating windows (can't close other windows when the command-line window is open)
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if
          vim.api.nvim_win_is_valid(win) and U.is_floating_win(win, { zen = false, tsc = false, dashboard = false })
        then
          vim.api.nvim_win_close(win, false)
          something_done = true
        end
      end
    end
  end

  if not is_cmdwin then
    vim.cmd("diffupdate")
  end
  -- vim.cmd("syntax sync fromstart")
  Snacks.util.redraw(vim.api.nvim_get_current_win()) -- vim.cmd("normal! <C-L>") -- vim.cmd.redraw({ bang = true })
  if opts.esc then
    vim.api.nvim_feedkeys(vim.keycode("<esc>"), "n", false)
  end
  return something_done
end

return M
