-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.maplocalleader = ","

local opt = vim.opt

opt.relativenumber = false
opt.spelllang:append("cjk") -- exclude East Asian characters from spell checking
opt.timeoutlen = vim.g.vscode and 1000 or 500 -- increase timeoutlen for mini.operators (`cr` and `cR`) since which-key v3
-- https://github.com/folke/dot/blob/master/nvim/lua/config/options.lua
opt.backup = true
opt.backupdir = vim.fn.stdpath("state") .. "/backup"
-- https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/basics.lua#L535
-- stylua: ignore
local win_borders_fillchars = {
  bold   = 'vert:┃,horiz:━,horizdown:┳,horizup:┻,verthoriz:╋,vertleft:┫,vertright:┣',
  dot    = 'vert:·,horiz:·,horizdown:·,horizup:·,verthoriz:·,vertleft:·,vertright:·',
  double = 'vert:║,horiz:═,horizdown:╦,horizup:╩,verthoriz:╬,vertleft:╣,vertright:╠',
  single = 'vert:│,horiz:─,horizdown:┬,horizup:┴,verthoriz:┼,vertleft:┤,vertright:├',
  solid  = 'vert: ,horiz: ,horizdown: ,horizup: ,verthoriz: ,vertleft: ,vertright: ',
}
opt.fillchars:append(win_borders_fillchars["bold"])

vim.g.user_is_termux = vim.env.TERMUX_VERSION ~= nil
-- failed to install basedpyright on Termux
if not vim.g.user_is_termux then
  vim.g.lazyvim_python_lsp = "basedpyright"
end
-- For holding layout like no-neck-pain.nvim when Auto Close is disabled
vim.g.user_neotree_auto_close = vim.g.user_is_termux

-- https://neovide.dev/configuration.html
if vim.g.neovide then
  vim.g.neovide_hide_mouse_when_typing = true
  -- both, only_left, only_right, none
  vim.g.neovide_input_macos_option_key_is_meta = "both"
  -- railgun, torpedo, pixiedust
  vim.g.neovide_cursor_vfx_mode = "railgun"
end
