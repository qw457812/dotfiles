-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local function lazyvim_augroup(name, clear)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = clear or false })
end

-- show cursor line only in active window
-- https://github.com/folke/dot/blob/master/nvim/lua/config/autocmds.lua
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
  callback = function()
    if vim.w.auto_cursorline then
      vim.wo.cursorline = true
      vim.w.auto_cursorline = nil
    end
  end,
})
vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
  callback = function()
    if vim.wo.cursorline then
      vim.w.auto_cursorline = true
      vim.wo.cursorline = false
    end
  end,
})

-- backups
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("better_backup", { clear = true }),
  callback = function(event)
    local file = vim.uv.fs_realpath(event.match) or event.match
    local backup = vim.fn.fnamemodify(file, ":p:~:h")
    backup = backup:gsub("[/\\]", "%%")
    vim.go.backupext = backup
  end,
})

-- disable LazyVim's auto command for wrap
local wrap_spell_opts = { group = lazyvim_augroup("wrap_spell"), event = "FileType" }
local wrap_spell_pattern = vim.tbl_map(function(autocmd)
  return autocmd.pattern
end, vim.api.nvim_get_autocmds(wrap_spell_opts))
-- https://github.com/LazyVim/LazyVim/issues/3692
-- alternative: vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_clear_autocmds(wrap_spell_opts)
-- create my own
vim.api.nvim_create_autocmd("FileType", {
  pattern = wrap_spell_pattern,
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- disable wrap for some filetypes
vim.api.nvim_create_autocmd("FileType", {
  -- pattern = vim.list_extend({
  --   "lazy",
  -- }, wrap_spell_pattern),
  pattern = {
    "lazy", -- Lazy Extras, alternative: https://github.com/aimuzov/LazyVimx/blob/00d45b2d746c36101b4cf1c5fe0b46d53cb6774a/lua/lazyvimx/extras/hacks/lazyvim-remove-extras-title.lua
  },
  callback = function()
    vim.defer_fn(function()
      vim.opt_local.wrap = false
    end, 100)
  end,
})

-- make it easier to scroll man/help files when opened inline with `<leader>sM`, `<leader>sh`, `:h`
-- maybe use BufRead/BufReadPost to map/safe_map(tzachar/highlight-undo.nvim?) `u`/`d` for all non-modifiable/readonly buffers?
-- for safe_map, check `LazyVim.safe_keymap_set` or `vim.tbl_isempty(vim.fn.maparg("u", "n", false, true))`
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "man", "help" },
  callback = function(event)
    local buf = event.buf
    -- don't change the keymaps for help files that we're editing
    if vim.bo[buf].filetype == "help" and vim.bo[buf].buftype ~= "help" then
      return
    end
    -- note that /etc/hosts (vim.bo.readonly == true) can be changed with warning "Changing a readonly file", but files where vim.bo.modifiable == false can't
    if vim.bo[buf].modifiable == false or vim.bo[buf].readonly == true then
      vim.keymap.set("n", "u", "<C-u>", { buffer = buf, silent = true, desc = "Scroll Up" })
      -- add `nowait = true` since we have a `dd` mapping defined in keymaps.lua
      vim.keymap.set("n", "d", "<C-d>", { buffer = buf, silent = true, desc = "Scroll Down", nowait = true })
    end
  end,
})

-- -- revert `lazyvim_close_with_q` auto command for help files that we're editing
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "help",
--   callback = function(event)
--     if vim.bo[event.buf].buftype ~= "help" then
--       vim.bo[event.buf].buflisted = true
--       pcall(vim.keymap.del, "n", "q", { buffer = event.buf })
--     end
--   end,
-- })
--
-- unlisted some filetypes (e.g. qf, checkhealth) in favor of bufferline.nvim
local close_with_q_pattern = vim.tbl_map(function(autocmd)
  return autocmd.pattern
end, vim.api.nvim_get_autocmds({ group = lazyvim_augroup("close_with_q"), event = "FileType" }))
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("unlisted", { clear = true }),
  -- pattern = vim.tbl_filter(function(pattern)
  --   return pattern ~= "help"
  -- end, close_with_q_pattern),
  pattern = close_with_q_pattern,
  callback = function(event)
    -- don't unlisted help files that we're editing
    if vim.bo[event.buf].filetype == "help" and vim.bo[event.buf].buftype ~= "help" then
      return
    end
    vim.bo[event.buf].buflisted = false
  end,
})
-- overwrite `lazyvim_close_with_q` auto command
-- copied from: https://github.com/AstroNvim/AstroNvim/blob/d771094986abced8c3ceae29a5a55585ecb0523a/lua/astronvim/plugins/_astrocore_autocmds.lua#L245
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = lazyvim_augroup("close_with_q", true),
  desc = "Make q close help, man, quickfix, dap floats",
  callback = function(args)
    -- Add cache for buffers that have already had mappings created
    if not vim.g.q_close_windows then
      vim.g.q_close_windows = {}
    end
    -- If the buffer has been checked already, skip
    if vim.g.q_close_windows[args.buf] then
      return
    end
    -- Mark the buffer as checked
    vim.g.q_close_windows[args.buf] = true
    -- Check to see if `q` is already mapped to the buffer (avoids overwriting)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(args.buf, "n")) do
      if map.lhs == "q" then
        return
      end
    end
    -- If there is no q mapping already and the buftype is a non-real file, create one
    if vim.tbl_contains({ "help", "nofile", "quickfix" }, vim.bo[args.buf].buftype) then
      vim.keymap.set("n", "q", "<Cmd>close<CR>", {
        desc = "Close window",
        buffer = args.buf,
        silent = true,
        nowait = true,
      })
    end
  end,
})
vim.api.nvim_create_autocmd("BufDelete", {
  group = lazyvim_augroup("close_with_q"),
  desc = "Clean up q_close_windows cache",
  callback = function(args)
    if vim.g.q_close_windows then
      vim.g.q_close_windows[args.buf] = nil
    end
  end,
})

-- -- colorcolumn
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "markdown" },
--   callback = function()
--     vim.opt_local.colorcolumn = "80"
--   end,
-- })
