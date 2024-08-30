-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

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
-- https://github.com/LazyVim/LazyVim/issues/3692
-- alternative: vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_clear_autocmds({ group = "lazyvim_wrap_spell" })
-- create my own
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- revert `lazyvim_close_with_q` auto command for help files that we're editing
vim.api.nvim_create_autocmd("FileType", {
  pattern = "help",
  callback = function(event)
    if vim.bo[event.buf].buftype ~= "help" then
      vim.bo[event.buf].buflisted = true
      pcall(vim.keymap.del, "n", "q", { buffer = event.buf })
    end
  end,
})

-- -- close some filetypes with <q>
-- -- see also: ../plugins/close.lua
-- -- https://github.com/appelgriebsch/Nv/blob/main/lua/config/autocmds.lua
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = {
--     "dap-float",
--     "httpResult",
--   },
--   callback = function(event)
--     vim.bo[event.buf].buflisted = false
--     vim.keymap.set("n", "q", "<cmd>close<cr>", {
--       buffer = event.buf,
--       silent = true,
--       desc = "Quit buffer",
--     })
--   end,
-- })

-- -- disable the concealing in some file formats
-- -- https://github.com/craftzdog/dotfiles-public/blob/master/.config/nvim/lua/config/autocmds.lua
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "markdown" },
--   callback = function()
--     vim.opt_local.conceallevel = 0
--   end,
-- })
