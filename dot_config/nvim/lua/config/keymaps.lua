-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- navigate to line start and end from home row
map({ "n", "v", "o" }, "H", "^", { desc = "Start of Line" })
map({ "n", "v", "o" }, "L", "$", { desc = "End of Line" })

-- quit
map("n", "<bs>", "<cmd>q<cr>", { desc = "Quit" })

-- save file
map("n", "<leader>fs", "<cmd>w<cr><esc>", { desc = "Save File" })

-- buffers
map("n", "<Up>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<Down>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

-- jumping
map("n", "<Left>", "<C-o>", { desc = "Go Back" })
map("n", "<Right>", "<C-i>", { desc = "Go Forward" })

-- TODO
-- <leader>fy
-- <leader>fY
