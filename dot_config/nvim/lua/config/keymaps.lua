-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local Lazy = require("lazy")
local LazyUtil = require("lazy.util")
local replace_home = require("util.path").replace_home_with_tilde

local del = vim.keymap.del

--- vim.keymap.set, silent by default
--- https://github.com/folke/dot/blob/5df77fa64728a333f4d58e35d3ca5d8590c4f928/nvim/lua/config/options.lua#L22
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? vim.keymap.set.Opts
local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- lazy/LazyVim
-- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/config/keymaps.lua
map("n", "<leader>l", "", { desc = "+lazy/lazyvim" })
del("n", "<leader>L")
map("n", "<leader>ll", "<cmd>Lazy<cr>", { desc = "Lazy" })
-- stylua: ignore start
map("n", "<leader>lc", function() LazyVim.news.changelog() end, { desc = "LazyVim Changelog" })
map("n", "<leader>lx", "<cmd>LazyExtras<cr>", { desc = "Extras" })
-- alternative: vim.fn.system({ "open", "https://lazyvim.org" }) or vim.cmd("silent !open https://lazyvim.org")
map("n", "<leader>ld", function() LazyUtil.open("https://lazyvim.org") end, { desc = "LazyVim Docs" })
map("n", "<leader>lD", function() LazyUtil.open("https://lazy.folke.io") end, { desc = "lazy.nvim Docs" })
map("n", "<leader>lr", function() LazyUtil.open("https://github.com/LazyVim/LazyVim") end, { desc = "LazyVim Repo" })
map("n", "<leader>lR", function() LazyUtil.open("https://github.com/folke/lazy.nvim") end, { desc = "lazy.nvim Repo" })
map("n", "<leader>lu", function() Lazy.update() end, { desc = "Lazy Update" })
map("n", "<leader>ls", function() Lazy.sync() end, { desc = "Lazy Sync" })
map("n", "<leader>lC", function() Lazy.check() end, { desc = "Lazy Check" })
-- stylua: ignore end

-- navigate to line start and end from home row
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
-- save file without formatting
map("n", "<leader>fS", "<cmd>noautocmd w<cr>", { desc = "Save File Without Formatting" })

-- buffers
-- see: akinsho/bufferline.nvim in ~/.config/nvim/lua/plugins/ui.lua
-- if you change the order of buffers :bnext and :bprevious will not respect the custom ordering
-- map("n", "<Up>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
-- map("n", "<Down>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<leader>ba", "<cmd>bufdo bd<cr>", { desc = "Delete All Buffers" })

-- jumping
map("n", "<Left>", "<C-o>", { desc = "Go Back" })
map("n", "<Right>", "<C-i>", { desc = "Go Forward" })

-- match
-- helix-style mappings | https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/config/keymaps.lua#L103
map({ "n", "x", "o" }, "mm", "%", { desc = "Goto matching bracket" })

-- map("n", "U", "<C-r>", { desc = "Redo" })

-- floating terminal
-- stylua: ignore
map("n", "<leader>.", function() LazyVim.terminal(nil, { cwd = vim.fn.expand("%:p:h") }) end, { desc = "Terminal (Buffer Dir)" })

-- windows
-- https://github.com/gpakosz/.tmux/blob/9cf49731cd785b76cf792046feed0e8275457918/.tmux.conf#L74
map("n", "<leader>_", "<C-W>v", { desc = "Split Window Right", remap = true })

if LazyVim.has("tmux.nvim") then
  -- Move to window
  -- https://github.com/aserowy/tmux.nvim/issues/92#issuecomment-1452428973
  map({ "n", "t" }, "<C-h>", [[<cmd>lua require("tmux").move_left()<cr>]], { desc = "Go to Left Window" })
  map({ "n", "t" }, "<C-j>", [[<cmd>lua require("tmux").move_bottom()<cr>]], { desc = "Go to Lower Window" })
  map({ "n", "t" }, "<C-k>", [[<cmd>lua require("tmux").move_top()<cr>]], { desc = "Go to Upper Window" })
  map({ "n", "t" }, "<C-l>", [[<cmd>lua require("tmux").move_right()<cr>]], { desc = "Go to Right Window" })
  -- Resize window
  -- note: A-hjkl for move lines (by both LazyVim's default keybindings and lazyvim.plugins.extras.editor.mini-move)
  -- need to disable macOS keybord shortcuts of mission control first
  -- TODO resize LazyVim's terminal
  map({ "n", "t" }, "<C-Left>", [[<cmd>lua require("tmux").resize_left()<cr>]], { desc = "Resize Window Left" })
  map({ "n", "t" }, "<C-Down>", [[<cmd>lua require("tmux").resize_bottom()<cr>]], { desc = "Resize Window Bottom" })
  map({ "n", "t" }, "<C-Up>", [[<cmd>lua require("tmux").resize_top()<cr>]], { desc = "Resize Window Top" })
  map({ "n", "t" }, "<C-Right>", [[<cmd>lua require("tmux").resize_right()<cr>]], { desc = "Resize Window Right" })
end

-- deleting without yanking empty line
map("n", "dd", function()
  local is_empty_line = vim.api.nvim_get_current_line():match("^%s*$")
  if is_empty_line then
    return '"_dd'
  else
    return "dd"
  end
end, { expr = true, desc = "Don't Yank Empty Line to Clipboard" })

-- https://github.com/wfxr/dotfiles/blob/661bfabf3b813fd8af79d881cd28b72582d4ccca/vim/nvim/lua/config/keymaps.lua#L35
map("n", "gV", "`[v`]", { desc = "Select last changed or yanked text" })

-- TODO search literal | https://vi.stackexchange.com/questions/17465/how-to-search-literally-without-any-regex-pattern
-- search inside visually highlighted text
map("x", "g/", "<esc>/\\%V", { desc = "Search Inside Visual Selection" })

-- https://github.com/rstacruz/vimfiles/blob/ee9a3e7e7f022059b6d012eff2e88c95ae24ff97/lua/config/keymaps.lua#L35
-- :let @+=expand('%:p')<cr>
map("n", "<leader>fy", function()
  local path = replace_home(vim.fn.expand("%:p"))
  vim.fn.setreg("+", path)
  LazyVim.info("Copied path: " .. path)
end, { desc = "Yank file path" })

map("n", "<leader>fY", function()
  local path = replace_home(vim.fn.expand("%:."))
  vim.fn.setreg("+", path)
  LazyVim.info("Copied path: " .. path)
end, { desc = "Yank file path from project" })

-- map("n", "<leader>fY", function()
--   local name = vim.fn.expand("%:t")
--   vim.fn.setreg("+", name)
--   LazyVim.info("Copied file name: " .. name)
-- end, { desc = "Yank file name" })

local function google_search(input)
  local query = input or vim.fn.expand("<cword>")
  LazyUtil.open("https://www.google.com/search?q=" .. query)
end
-- conflict with "Buffer Local Keymaps (which-key)" defined in ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/editor.lua
-- map("n", "<leader>?", google_search, { desc = "Google Search Current Word" })
map("x", "<leader>?", function()
  local g_orig = vim.fn.getreg("g")
  vim.cmd([[silent! normal! "gy]])
  google_search(vim.fn.getreg("g"))
  vim.fn.setreg("g", g_orig)
end, { desc = "Google Search" })

if vim.g.neovide then
  -- fix cmd-v for paste in insert, command, terminal (for fzf-lua) mode
  -- https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste
  -- map("c", "<D-v>", "<C-r>+")
  -- https://github.com/neovide/neovide/issues/1263#issuecomment-1972013043
  -- stylua: ignore
  map({ "i", "c", "t" }, "<D-v>", function() vim.api.nvim_paste(vim.fn.getreg("+"), true, -1) end, { desc = "Paste" })
end
