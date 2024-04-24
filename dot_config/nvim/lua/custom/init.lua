local autocmd = vim.api.nvim_create_autocmd

-- Auto resize panes when resizing nvim window
-- autocmd("VimResized", {
--   pattern = "*",
--   command = "tabdo wincmd =",
-- })

-- xyq
local g = vim.g

-- :help copilot
-- https://github.com/LunarVim/LunarVim/issues/1856#issuecomment-954224770
-- g.copilot_no_tab_map = true
-- g.copilot_assume_mapped = true
-- g.copilot_tab_fallback = ""

-- :h lua-highlight
-- vim.cmd("au TextYankPost * silent! lua vim.highlight.on_yank({timeout=250})")
-- https://github.com/BrunoKrugel/dotfiles/blob/master/utils/autocmd.lua
autocmd("TextYankPost", {
  command = "silent! lua vim.highlight.on_yank({timeout=250})",
})

-- https://github.com/iamcco/markdown-preview.nvim#markdownpreview-config
-- use a custom port to start server or empty for random
-- work with Dark Reader extension for Browser
g.mkdp_port = '12388'
