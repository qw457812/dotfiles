-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.relativenumber = false
opt.spelllang = { "en", "cjk" } -- exclude East Asian characters from spell checking
opt.timeoutlen = vim.g.vscode and 1000 or 500 -- increase timeoutlen for mini.operators (`cr` and `cR`) since which-key v3
-- https://github.com/folke/dot/blob/master/nvim/lua/config/options.lua
opt.backup = true
opt.backupdir = vim.fn.stdpath("state") .. "/backup"

-- Python LSP Server: use basedpyright instead of pyright
vim.g.lazyvim_python_lsp = "basedpyright"

vim.g.user_is_termux = vim.env.TERMUX_VERSION ~= nil
vim.g.user_neotree_auto_close = vim.g.user_is_termux

-- https://neovide.dev/configuration.html
if vim.g.neovide then
  vim.g.neovide_hide_mouse_when_typing = true
  -- both, only_left, only_right, none
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"
  -- railgun, torpedo, pixiedust
  vim.g.neovide_cursor_vfx_mode = "railgun"
end
