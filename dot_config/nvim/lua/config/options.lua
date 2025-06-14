-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.maplocalleader = ","

local opt = vim.opt

opt.relativenumber = false
opt.spelllang:append("cjk") -- exclude East Asian characters from spell checking
opt.timeoutlen = vim.g.vscode and 1000 or 500 -- increase timeoutlen for mini.operators `cX` since which-key v3
-- opt.shell = vim.fn.executable("fish") == 1 and "fish" or opt.shell
opt.backup = true
opt.backupdir = vim.fn.stdpath("state") .. "/backup"
-- ignore builtin colorschemes for Snacks.picker.colorschemes(), see #969
-- alternative: vim.opt.wildignore:append(vim.api.nvim_get_runtime_file("colors/*.{vim,lua}", true))
opt.wildignore:append({ vim.env.VIMRUNTIME .. "/colors/*.vim", vim.env.VIMRUNTIME .. "/colors/*.lua" })
-- copied from: https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/basics.lua#L535
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
vim.g.user_close_key = "<BS>" -- easy to reach for Glove80
vim.g.user_exit_key = "<Leader><BS>" -- would overwrite "go up one level" of which-key
vim.g.user_term_close_key = "<S-BS>"
vim.g.user_is_wezterm = not vim.g.neovide and vim.env.WEZTERM_UNIX_SOCKET ~= nil
vim.g.user_is_kitty = not vim.g.neovide and vim.env.KITTY_PID ~= nil
vim.g.user_is_tmux = not vim.g.neovide and vim.env.TMUX ~= nil
vim.g.user_is_termux = vim.env.TERMUX_VERSION ~= nil
-- using karabiner for neovide
vim.g.user_distinguish_ctrl_i_tab = vim.g.user_is_kitty or vim.g.user_is_wezterm or vim.g.neovide
vim.g.user_transparent_background = vim.g.user_is_wezterm or vim.g.user_is_kitty
-- TODO: Snacks.explorer
vim.g.user_explorer_width = math.max(35, math.min(50, math.floor(vim.o.columns * 0.25)))
-- holding layout like no-neck-pain.nvim
-- the `vim.g.user_explorer_auto_open` setting will be ignored if `vim.g.user_explorer_auto_close` is set to true
vim.g.user_explorer_auto_open = vim.o.columns - vim.g.user_explorer_width >= 120
vim.g.user_explorer_auto_close = vim.g.user_is_termux
if vim.env.SHELL_COMMAND_EDITOR then
  -- set in fish_user_key_bindings.fish before calling `edit_command_buffer`
  vim.g.shell_command_editor = true
end
if vim.env.KITTY_SCROLLBACK_NVIM == "true" then
  vim.g.terminal_scrollback_pager = true
end
if lazyvim_docs then
  -- set in config.fish via `alias vimpager 'nvim - --cmd "lua vim.g.pager = true" -c "lua require(\'util.terminal\').colorize()"'`
  vim.g.pager = false
  -- set in config.fish via `set -x MANPAGER 'nvim --cmd "lua vim.g.manpager = true" +Man!'`
  vim.g.manpager = false
  -- set in kitty.conf via `scrollback_pager nvim --cmd "lua vim.g.terminal_scrollback_pager = true" -c "lua require('util.terminal').colorize()"`
  vim.g.terminal_scrollback_pager = false
end
---@type "neo-tree.nvim"|"snacks.nvim"|"oil.nvim"|"mini.files"|"yazi.nvim"|"telescope-file-browser.nvim"
vim.g.user_hijack_netrw = (
  vim.g.shell_command_editor
  or vim.g.pager
  or vim.g.manpager
  or vim.g.terminal_scrollback_pager
)
    and "snacks.nvim"
  or "oil.nvim"

-- https://github.com/monoira/.dotfiles/blob/bd69b59d228f4b23a3e190cbd3c67a79e6a396e2/nvim/.config/nvim/lua/config/options.lua#L36
-- https://github.com/ahmedkhalf/project.nvim/blob/8c6bad7d22eef1b71144b401c9f74ed01526a4fb/lua/project_nvim/config.lua#L17
vim.g.root_spec = { "lsp", { ".git", "lua", ".svn" }, "cwd" }
vim.g.root_lsp_ignore = vim.list_extend(vim.g.root_lsp_ignore or {}, { "copilot_ls", "rime_ls", "harper_ls" })
vim.g.deprecation_warnings = true
vim.g.trouble_lualine = false
vim.g.lazyvim_blink_main = not vim.g.user_is_termux
-- failed to install basedpyright on termux via mason
vim.g.lazyvim_python_lsp = not vim.g.user_is_termux and "basedpyright" or vim.g.lazyvim_python_lsp
-- vim.env.FZF_DEFAULT_OPTS = "" -- better coop with fzf-lua

vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

if vim.g.user_is_termux then
  opt.swapfile = false

  -- https://github.com/nvim-lua/plenary.nvim/issues/536#issuecomment-1799807408
  -- https://github.com/nvim-lua/plenary.nvim/blob/f031bef84630f556c2fb81215826ea419d81f4e9/lua/plenary/curl.lua#L81
  vim.env.XDG_RUNTIME_DIR = vim.env.XDG_RUNTIME_DIR or vim.env.PREFIX .. "/tmp"
end

if vim.g.neovide then
  vim.g.user_auto_root = true -- what's the point of using "/" as cwd?
  -- vim.g.user_auto_session = true
  vim.g.snacks_animate = false

  vim.g.neovide_hide_mouse_when_typing = true
  vim.g.neovide_input_macos_option_key_is_meta = "both"
  vim.g.neovide_scroll_animation_length = 0.150
  vim.g.neovide_cursor_animation_length = 0.04
  -- vim.g.neovide_cursor_vfx_mode = "railgun" -- railgun, torpedo, pixiedust
  vim.g.neovide_opacity = vim.g.user_transparent_background and 0.0 or vim.g.neovide_opacity
end

if vim.g.vscode then
  opt.laststatus = 0
end

U.on_very_very_lazy(function()
  -- after VeryLazy
  vim.g.user_very_very_lazy = true
end)
