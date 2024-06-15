-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- navigate to line start and end from home row
map({ "n", "v", "o" }, "H", "^", { desc = "Start of line" })
map({ "n", "v", "o" }, "L", "$", { desc = "End of line" })

-- quit
map("n", "<bs>", "<cmd>q<cr>", { desc = "Quit" })

-- save file
map("n", "<leader>fs", "<cmd>w<cr><esc>", { desc = "Save File" })
