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

vim.g.user_is_wezterm = vim.env.WEZTERM_UNIX_SOCKET ~= nil
vim.g.user_is_tmux = vim.env.TMUX ~= nil
vim.g.user_is_termux = vim.env.TERMUX_VERSION ~= nil
vim.g.user_transparent_background = vim.g.user_is_wezterm
-- failed to install basedpyright on termux via mason
vim.g.lazyvim_python_lsp = vim.g.user_is_termux and nil or "basedpyright"
-- hijack_netrw: neo-tree.nvim, oil.nvim, mini.files, yazi.nvim, telescope-file-browser.nvim
vim.g.user_default_explorer = "oil.nvim"
-- holding layout like no-neck-pain.nvim by disabling neo-tree auto close
vim.g.user_neotree_auto_close = vim.g.user_is_termux

-- https://neovide.dev/configuration.html
if vim.g.neovide then
  vim.g.neovide_hide_mouse_when_typing = true
  -- both, only_left, only_right, none
  vim.g.neovide_input_macos_option_key_is_meta = "both"
  -- railgun, torpedo, pixiedust
  vim.g.neovide_cursor_vfx_mode = "railgun"
  if vim.g.user_transparent_background then
    vim.g.neovide_transparency = 0.0
  end
end
