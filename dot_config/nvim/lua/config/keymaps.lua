-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- navigate to line start and end from home row
-- TODO not work in telescope's input box's normal mode
map({ "n", "x", "o" }, "H", "^", { desc = "Goto line start" })
map({ "n", "x", "o" }, "L", "$", { desc = "Goto line end" })

-- quit
-- map("n", "<bs>", "<cmd>wincmd q<cr>", { desc = "Close window" })
map("n", "<bs>", "<cmd>q<cr>", { desc = "Quit" })

-- save file
map("n", "<leader>fs", "<cmd>w<cr><esc>", { desc = "Save File" })

-- buffers
map("n", "<Up>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<Down>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

-- jumping
map("n", "<Left>", "<C-o>", { desc = "Go Back" })
map("n", "<Right>", "<C-i>", { desc = "Go Forward" })

-- match
-- helix-style mappings | https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/config/keymaps.lua#L103
map({ "n", "x", "o" }, "mm", "%", { desc = "Goto matching bracket" })

-- TODO
-- <leader>fy
-- <leader>fY
