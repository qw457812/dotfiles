-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt

opt.relativenumber = false -- Relative line numbers

-- https://neovide.dev/configuration.html
if vim.g.neovide then
  vim.g.neovide_hide_mouse_when_typing = true
  -- both, only_left, only_right, none
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"
  -- railgun, torpedo, pixiedust
  vim.g.neovide_cursor_vfx_mode = "railgun"
end
