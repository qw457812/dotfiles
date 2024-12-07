-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local Lazy = require("lazy")
local LazyUtil = require("lazy.util")
local LazyViewConfig = require("lazy.view.config")

local map = U.keymap.map
local safe_map = U.keymap.safe_map
local del = U.keymap.del

local cmdwin = function(type)
  return function()
    if package.loaded["zen-mode"] and require("zen-mode.view").is_open() then
      require("zen-mode").close()
    end
    -- vim.api.nvim_feedkeys("q" .. type .. "G", "n", true)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q" .. type .. "G", true, true, true), "n", false)
  end
end

-- https://github.com/rafi/vim-config/blob/3689ae1ba113e2b8c6d12f17281fd14d91e58027/lua/rafi/config/keymaps.lua#L122
local blockwise_force = function(key)
  local c_v = vim.api.nvim_replace_termcodes("<C-v>", true, false, true)
  local keyseq = {
    I = { v = "<C-v>I", V = "<C-v>^o^I", [c_v] = "I" },
    A = { v = "<C-v>A", V = "<C-v>0o$A", [c_v] = "A" },
    gI = { v = "<C-v>0I", V = "<C-v>0o$I", [c_v] = "0I" },
  }
  return function()
    return keyseq[key][vim.fn.mode()]
  end
end

local function is_empty_line()
  return vim.api.nvim_get_current_line():match("^%s*$")
end

-- -- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/keybindings.lua#L234
-- map("n", "<cr>", "gd", { desc = "Goto local Declaration" })
-- -- restore default behavior of `<cr>`, which is overridden by my mapping above
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "qf", "neo-tree-popup" },
--   callback = function(event)
--     map("n", "<cr>", "<cr>", { buffer = event.buf })
--   end,
-- })
-- vim.api.nvim_create_autocmd("CmdWinEnter", {
--   callback = function(event)
--     map("n", "<cr>", "<cr>", { buffer = event.buf })
--   end,
-- })

-- basics
if vim.g.user_is_wezterm then
  -- To distinguish <C-I> and <Tab>, you could map another key, say <M-I>, to <C-I> in neovim,
  -- and then map ctrl+i to send <M-I> key sequence in your terminal setting.
  -- See: `:h tui-input`
  map({ "n", "i", "c", "v", "o", "t" }, "<M-i>", "<C-i>", { desc = "<C-i>" })
  map("n", "<tab>", "<c-w>w", { desc = "Switch to Other Window", remap = true })
end

-- map("n", "l", "foldclosed('.') != -1 ? 'zo' : 'l'", { expr = true })
map({ "n", "x" }, "l", U.keymap.foldopen_l, { desc = "Right" })

-- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/keybindings.lua#L19
map({ "n", "x" }, "H", "&wrap ? 'g^' : '0^'", { desc = "Goto line start", expr = true }) -- use 0^ to scroll fully to the left
map("o", "H", "&wrap ? 'g^' : '^'", { desc = "Goto line start", expr = true })
-- map("n", "L", "foldclosed('.') != -1 ? 'zO' : v:count ? '$' : &wrap ? 'g$' : '$'", { desc = "Goto line end", expr = true })
map("n", "L", "(v:count ? '$' : &wrap ? 'g$' : '$').'zv'", { desc = "Goto line end", expr = true })
map("o", "L", "v:count ? '$' : &wrap ? 'g$' : '$'", { desc = "Goto line end", expr = true })
-- TODO: to the last non-blank character of the line when wrapped
-- stylua: ignore
map("x", "L", "(mode() == nr2char(22) ? '$' : v:count ? 'g_' : &wrap ? 'g$' : 'g_').'zv'", { desc = "Goto line end", expr = true }) -- see `:h v_$` for <C-v>$
LazyViewConfig.commands.home.key = "gH" -- see: #411 #133
LazyViewConfig.commands.log.key = "gL"

-- bufferline.nvim: if you change the order of buffers :bnext and :bprevious will not respect the custom ordering
safe_map("n", { "J", "<Down>" }, "<cmd>bnext<cr>", { desc = "Next Buffer" })
safe_map("n", { "K", "<Up>" }, "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map({ "n", "x" }, "gj", "J", { desc = "Join Lines" })
map({ "n", "x" }, "gk", "K", { desc = "Keywordprg" }) -- not necessary
LazyViewConfig.keys.hover = "gk"

map("n", "<Left>", "<C-o>", { desc = "Go Back" })
map("n", "<Right>", "<C-i>", { desc = "Go Forward" })

-- stylua: ignore
map("n", "<esc>", U.keymap.clear_ui_esc, { desc = "Escape and Clear hlsearch or notifications or Close floating window(s)" })

-- helix-style mappings | https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/config/keymaps.lua#L103
map({ "n", "x", "o" }, "mm", "%", { desc = "Goto matching bracket", remap = true }) -- remap to matchit
safe_map("n", "U", "<C-r>", { desc = "Redo" }) -- highlight-undo.nvim

-- stylua: ignore start
map("n", "dd", function() return is_empty_line() and '"_dd' or "dd" end, { expr = true, desc = "Don't Yank Empty Line to Clipboard" })
map("n", "i",  function() return is_empty_line() and '"_cc' or "i" end,  { expr = true, desc = "Indented i on Empty Line" })
-- stylua: ignore end

-- Better block-wise operations on selected area
map("x", "I", blockwise_force("I"), { expr = true, desc = "Blockwise Insert" })
map("x", "gI", blockwise_force("gI"), { expr = true, desc = "Blockwise Insert" })
map("x", "A", blockwise_force("A"), { expr = true, desc = "Blockwise Append" })

if not LazyVim.has("nvim-hlslens") then
  del("n", { "n", "N" })
end
del({ "x", "o" }, { "n", "N" })

-- buffers
-- ":e #" doesn't work if the alternate buffer doesn't have a file name, while CTRL-^ still works then
map("n", { "<leader>`", "<leader>bb" }, "<C-^>", { desc = "Switch to Other Buffer" })
safe_map("n", "<leader>ba", "<cmd>bufdo bd<cr>", { desc = "Delete All Buffers" }) -- bufferline.nvim
-- stylua: ignore
map("n", "<leader>bA", function() Snacks.bufdelete.all() end, { desc = "Delete All Buffers" })

-- windows
map("n", "<leader>_", "<C-W>v", { desc = "Split Window Right", remap = true })

-- tabs
del("n", { "<leader><tab>f", "<leader><tab>l", "<leader><tab>]", "<leader><tab>[" })
map("n", "<leader><tab>H", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map("n", "<leader><tab>L", "<cmd>tablast<cr>", { desc = "Last Tab" })
map("n", "]<tab>", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "[<tab>", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

-- terminal
-- stylua: ignore
map("n", "<c-space>", function() Snacks.terminal(nil, { cwd = vim.fn.expand("%:p:h") }) end, { desc = "Terminal (Buffer Dir)" })
map("t", "<c-space>", "<cmd>close<cr>", { desc = "Hide Terminal" })

-- files
map("n", "<leader>fs", "<cmd>w<cr><esc>", { desc = "Save File" })
map("n", "<leader>fS", "<cmd>noautocmd w<cr>", { desc = "Save File Without Formatting" })
map({ "i", "x", "n", "s" }, "<a-s>", "<cmd>noautocmd w<cr><esc>", { desc = "Save File Without Formatting" })
map({ "i", "x", "n", "s" }, "<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
map("n", "<D-r>", vim.cmd.edit, { desc = "Reload File" })

-- https://github.com/rstacruz/vimfiles/blob/ee9a3e7e7f022059b6d012eff2e88c95ae24ff97/lua/config/keymaps.lua#L35
-- https://github.com/nvim-lualine/lualine.nvim/blob/b431d228b7bbcdaea818bdc3e25b8cdbe861f056/lua/lualine/components/filename.lua#L74
-- :let @+=expand('%:p:~')<cr>
-- <cmd>call setreg('+', expand('%:p:~'))<cr>
map("n", "<leader>fy", function()
  -- local path = vim.fn.expand("%:p:~")
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:~") or ""
  vim.fn.setreg(vim.v.register, path)
  LazyVim.info(path, { title = "Copied Path" })
end, { desc = "Yank file absolute path" })
map("n", "<leader>fY", function()
  -- local path = vim.fn.expand("%:~:.")
  -- local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.") or ""
  local path = require("plenary.path"):new(vim.api.nvim_buf_get_name(0)):make_relative(LazyVim.root())
  vim.fn.setreg(vim.v.register, path)
  LazyVim.info(path, { title = "Copied Relative Path" })
end, { desc = "Yank file relative path" })
-- map("n", "<leader>fY", function()
--   local name = vim.fn.expand("%:t")
--   vim.fn.setreg(vim.v.register, name)
--   LazyVim.info(("Copied file name: `%s`"):format(name))
-- end, { desc = "Yank file name" })

-- Add empty lines before and after cursor line supporting dot-repeat
-- https://github.com/JulesNP/nvim/blob/36b04ae414b98e67a80f15d335c73744606a33d7/lua/keymaps.lua#L80
-- map("n", "gO", function() vim.cmd("normal! m`" .. vim.v.count .. vim.api.nvim_replace_termcodes("O<esc>``", true, true, true)) end, { desc = "Put empty line above" })
-- map("n", "go", function() vim.cmd("normal! m`" .. vim.v.count .. vim.api.nvim_replace_termcodes("o<esc>``", true, true, true)) end, { desc = "Put empty line below" })
-- https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/basics.lua#L579
-- map('n', 'gO', "<Cmd>call append(line('.') - 1, repeat([''], v:count1))<CR>") -- without dot-repeat
-- map('n', 'go', "<Cmd>call append(line('.'),     repeat([''], v:count1))<CR>") -- without dot-repeat
map("n", "gO", "v:lua.require'util.keymap'.put_empty_line(v:true)", { expr = true, desc = "Put empty line above" })
map("n", "go", "v:lua.require'util.keymap'.put_empty_line(v:false)", { expr = true, desc = "Put empty line below" })

-- https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/basics.lua#L589
-- map("n", "gV", '"`[" . strpart(getregtype(), 0, 1) . "`]"', { expr = true, replace_keycodes = false, desc = "Visually select changed text" })
-- https://github.com/gregorias/coerce.nvim#tips--tricks
-- stylua: ignore
map("n", "gp", function() vim.api.nvim_feedkeys("`[" .. vim.fn.strpart(vim.fn.getregtype(), 0, 1) .. "`]", "n", false) end, { desc = "Reselect last put/yanked/changed text" })

-- use `silent = false` for it to make effect immediately
map("x", "g/", "<esc>/\\%V", { silent = false, desc = "Search inside visual selection" })

map("n", "g/", cmdwin("/"), { desc = "command-line window (forward search)" })
map("n", "g?", cmdwin("?"), { desc = "command-line window (backward search)" })
map({ "n", "x" }, "g:", cmdwin(":"), { desc = "command-line window (Ex command)" })

map("n", "g.", "@:", { desc = "Repeat last command-line" })

-- works even with `spell=false`
map("n", "z.", "1z=", { desc = "Fix Spelling" })

map("s", "<bs>", "<C-o>s", { desc = "Inside a snippet (nvim-cmp), use backspace to remove the placeholder" })

-- toggle options
Snacks.toggle.option("number", { name = "Line Number" }):map("<leader>ul")
U.toggle.diagnostic_virtual_text:map("<leader>ud")
U.toggle.diagnostics:map("<leader>uD")
if not LazyVim.has("nvim-scrollbar") then
  -- stylua: ignore
  Snacks.toggle.option("laststatus", { off = 0, on = vim.o.laststatus > 0 and vim.o.laststatus or 3, name = "Status Line" }):map("<leader>uS")
end

-- lazy/LazyVim
map("n", "<leader>l", "", { desc = "+lazy/lazyvim" })
map("n", "<leader>ll", "<cmd>Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>lx", "<cmd>LazyExtras<cr>", { desc = "Extras" })
map("n", "<leader>lu", Lazy.update, { desc = "Lazy Update" })
map("n", "<leader>ls", Lazy.sync, { desc = "Lazy Sync" })
map("n", "<leader>lc", Lazy.check, { desc = "Lazy Check" })
del("n", "<leader>L")
-- stylua: ignore start
map("n", "<leader>lL", function() LazyVim.news.changelog() end, { desc = "LazyVim Changelog" })
map("n", "<leader>lN", function() LazyVim.news.lazyvim() end, { desc = "LazyVim News" })
-- alternative: vim.ui.open("https://lazyvim.org")
map("n", "<leader>ld", function() LazyUtil.open("https://lazyvim.org") end, { desc = "LazyVim Docs" })
map("n", "<leader>lD", function() LazyUtil.open("https://lazy.folke.io") end, { desc = "lazy.nvim Docs" })
map("n", "<leader>lr", function() LazyUtil.open("https://github.com/LazyVim/LazyVim") end, { desc = "LazyVim Repo" })
map("n", "<leader>lR", function() LazyUtil.open("https://github.com/folke/lazy.nvim") end, { desc = "lazy.nvim Repo" })
-- stylua: ignore end

local function lint_info()
  local lint = require("lint")
  -- see: ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/linting.lua
  local linters = lint._resolve_linter_by_ft(vim.bo.filetype)
  linters = vim.tbl_filter(function(name)
    local exists = lint.linters[name] ~= nil
    if not exists then
      LazyVim.warn("Linter not found: " .. name, { title = "Linters" })
    end
    return exists
  end, linters)
  if vim.tbl_isempty(linters) then
    LazyVim.warn("No linters available", { title = "Linters" })
    return
  end

  local ctx = { filename = vim.api.nvim_buf_get_name(0) }
  ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
  -- LazyVim extension `condition`
  local function cond(name)
    local linter = lint.linters[name]
    return not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
  end
  local lines = { "# Condition" }
  for _, linter in ipairs(linters) do
    lines[#lines + 1] = ("- [%s] **%s**"):format(cond(linter) and "x" or " ", linter)
  end
  LazyVim.info(lines, { title = "Linters" })
end

local function news()
  Snacks.win({
    file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
    width = 0.6,
    height = 0.6,
    wo = {
      spell = false,
      wrap = false,
      signcolumn = "yes",
      statuscolumn = " ",
      conceallevel = 3,
    },
  })
end

-- info
map("n", "<leader>i", "", { desc = "+info" })
map("n", "<leader>if", "<cmd>LazyFormatInfo<cr>", { desc = "Format" })
map("n", "<leader>ic", "<cmd>ConformInfo<cr>", { desc = "Conform" })
map("n", "<leader>ir", "<cmd>LazyRoot<cr>", { desc = "Root" })
map("n", "<leader>iL", lint_info, { desc = "Lint" })
-- stylua: ignore
map("n", "<leader>iC", function() LazyVim.info(vim.g.colors_name, { title = "ColorScheme" }) end, { desc = "ColorScheme" })
-- alternative: `:h news` or `LazyVim.news.neovim()`
map("n", "<leader>iN", news, { desc = "Neovim News" })

-- local function google_search(input)
--   local query = input or vim.fn.expand("<cword>")
--   LazyUtil.open("https://www.google.com/search?q=" .. query)
-- end
-- -- stylua: ignore
-- map("x", "<leader>?", function() google_search(U.get_visual_selection()) end, { desc = "Google Search" })

-- https://github.com/neovide/neovide/issues/1263#issuecomment-1972013043
local function paste()
  vim.api.nvim_paste(vim.fn.getreg(vim.v.register), true, -1)
end

if vim.g.user_is_termux then
  map({ "i", "c", "t" }, "<C-v>", paste, { desc = "Paste" })
end

if vim.g.neovide then
  -- fix cmd-v for paste in insert, command, terminal (for fzf-lua) mode
  -- https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste
  -- map("c", "<D-v>", "<C-r>+")
  -- https://github.com/neovide/neovide/issues/1263#issuecomment-1972013043
  map({ "i", "c", "t" }, "<D-v>", paste, { desc = "Paste" })
  U.toggle.neovide_animations:map("<leader>ua")
end
