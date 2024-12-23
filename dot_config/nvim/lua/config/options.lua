-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.maplocalleader = ","

local opt = vim.opt

opt.relativenumber = false
opt.spelllang:append("cjk") -- exclude East Asian characters from spell checking
opt.timeoutlen = vim.g.vscode and 1000 or 500 -- increase timeoutlen for mini.operators (`cr` and `cR`) since which-key v3
opt.shell = "fish"
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

-- close buffers, windows, or exit vim with the same single keypress
vim.g.user_close_key = "<bs>" -- easy to reach for Glove80
-- exit nvim
vim.g.user_exit_key = "<leader>" .. vim.g.user_close_key -- would overwrite "go up one level" of which-key
-- close terminals
vim.g.user_term_close_key = "<S-bs>"
vim.g.user_is_wezterm = vim.env.WEZTERM_UNIX_SOCKET ~= nil
vim.g.user_is_kitty = vim.env.KITTY_PID ~= nil
vim.g.user_is_tmux = vim.env.TMUX ~= nil
vim.g.user_is_termux = vim.env.TERMUX_VERSION ~= nil
vim.g.user_transparent_background = vim.g.user_is_wezterm
vim.g.user_hijack_netrw = "oil.nvim" -- neo-tree.nvim, oil.nvim, mini.files, yazi.nvim, telescope-file-browser.nvim
-- holding layout like no-neck-pain.nvim by disabling neo-tree auto close
vim.g.user_neotree_auto_close = vim.g.user_is_termux
vim.g.user_auto_root = false -- mess up Restore Session

-- https://github.com/monoira/.dotfiles/blob/bd69b59d228f4b23a3e190cbd3c67a79e6a396e2/nvim/.config/nvim/lua/config/options.lua#L36
-- https://github.com/ahmedkhalf/project.nvim/blob/8c6bad7d22eef1b71144b401c9f74ed01526a4fb/lua/project_nvim/config.lua#L17
vim.g.root_spec = { "lsp", { ".git", "lua", ".svn", "pom.xml" }, "cwd" }
vim.g.lazyvim_blink_main = not vim.g.user_is_termux
vim.g.trouble_lualine = false
-- failed to install basedpyright on termux via mason
vim.g.lazyvim_python_lsp = not vim.g.user_is_termux and "basedpyright" or vim.g.lazyvim_python_lsp
vim.g.deprecation_warnings = true

-- https://neovide.dev/configuration.html
if vim.g.neovide then
  vim.g.neovide_hide_mouse_when_typing = true
  vim.g.neovide_input_macos_option_key_is_meta = "both"
  vim.g.neovide_cursor_vfx_mode = "railgun" -- railgun, torpedo, pixiedust
  if vim.g.user_transparent_background then
    vim.g.neovide_transparency = 0.0
  end
end
