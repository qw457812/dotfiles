-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- navigate to line start and end from home row
-- TODO not work in telescope's input box's normal mode
map({ "n", "x", "o" }, "H", "^", { desc = "Goto line start" })
map({ "n", "o" }, "L", "$", { desc = "Goto line end" })
-- https://github.com/v1nh1shungry/.dotfiles/blob/d8a0f6fd2766d0ec9ce5d5b4ccd55b3cc4130c1a/nvim/lua/dotfiles/core/keymaps.lua#L74
map("x", "L", "g_", { desc = "Goto line end" })

-- quit
-- map("n", "<bs>", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<bs>", "<cmd>qa<cr>", { desc = "Quit All" })
-- map("n", "<bs>", LazyVim.ui.bufremove, { desc = "Delete Buffer" })
-- map("n", "<bs>", "<cmd>:bd<cr>", { desc = "Delete Buffer and Window" })
-- map("n", "<bs>", "<cmd>wincmd q<cr>", { desc = "Close window" })

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

-- map("n", "U", "<C-r>", { desc = "Redo" })

-- https://github.com/rstacruz/vimfiles/blob/ee9a3e7e7f022059b6d012eff2e88c95ae24ff97/lua/config/keymaps.lua#L35
-- :let @+=expand('%:p')<cr>
map("n", "<leader>fy", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  LazyVim.info("Copied path: " .. path)
end, { desc = "Yank file path" })

map("n", "<leader>fY", function()
  local path = vim.fn.expand("%:.")
  vim.fn.setreg("+", path)
  LazyVim.info("Copied path: " .. path)
end, { desc = "Yank file path from project" })

-- map("n", "<leader>fY", function()
--   local name = vim.fn.expand("%:t")
--   vim.fn.setreg("+", name)
--   LazyVim.info("Copied file name: " .. name)
-- end, { desc = "Yank file name" })

-- make the `-` key reveal the current file, or if in an unsaved file, the current working directory
-- :h neo-tree-configuration
map("n", "-", function()
  local reveal_file = vim.fn.expand("%:p")
  if reveal_file == "" then
    reveal_file = vim.fn.getcwd()
  else
    local f = io.open(reveal_file, "r")
    if f then
      f.close(f)
    else
      reveal_file = vim.fn.getcwd()
    end
  end
  require("neo-tree.command").execute({
    action = "focus", -- OPTIONAL, this is the default value
    source = "filesystem", -- OPTIONAL, this is the default value
    position = "left", -- OPTIONAL, this is the default value
    reveal_file = reveal_file, -- path to file or folder to reveal
    reveal_force_cwd = true, -- change cwd without asking if needed
  })
end, { desc = "Open neo-tree at current file or working directory" })

if vim.g.neovide then
  -- fix cmd-v for paste in insert, command, terminal (for fzf-lua) mode
  -- https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste
  -- map("c", "<D-v>", "<C-r>+")
  -- https://github.com/neovide/neovide/issues/1263#issuecomment-1972013043
  map({ "i", "c", "t" }, "<D-v>", function()
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
  end, { desc = "Paste", noremap = true, silent = true })
end
