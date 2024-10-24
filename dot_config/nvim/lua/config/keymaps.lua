-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local Lazy = require("lazy")
local LazyUtil = require("lazy.util")
local LazyViewConfig = require("lazy.view.config")

local map = U.keymap
local map_del = vim.keymap.del

-- lazy/LazyVim
-- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/config/keymaps.lua
map("n", "<leader>l", "", { desc = "+lazy/lazyvim" })
map_del("n", "<leader>L")
map("n", "<leader>ll", "<cmd>Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>lx", "<cmd>LazyExtras<cr>", { desc = "Extras" })
-- stylua: ignore start
map("n", "<leader>lL", function() LazyVim.news.changelog() end, { desc = "LazyVim Changelog" })
-- use `:h news` instead of `LazyVim.news.neovim()`
map("n", "<leader>lN", function() LazyVim.news.lazyvim() end, { desc = "LazyVim News" })
-- alternative: vim.fn.system({ "open", "https://lazyvim.org" }) or vim.cmd("silent !open https://lazyvim.org")
map("n", "<leader>ld", function() LazyUtil.open("https://lazyvim.org") end, { desc = "LazyVim Docs" })
map("n", "<leader>lD", function() LazyUtil.open("https://lazy.folke.io") end, { desc = "lazy.nvim Docs" })
map("n", "<leader>lr", function() LazyUtil.open("https://github.com/LazyVim/LazyVim") end, { desc = "LazyVim Repo" })
map("n", "<leader>lR", function() LazyUtil.open("https://github.com/folke/lazy.nvim") end, { desc = "lazy.nvim Repo" })
-- stylua: ignore end
map("n", "<leader>lu", Lazy.update, { desc = "Lazy Update" })
map("n", "<leader>ls", Lazy.sync, { desc = "Lazy Sync" })
map("n", "<leader>lc", Lazy.check, { desc = "Lazy Check" })

-- plugin info
-- https://github.com/jacquin236/minimal-nvim/blob/main/lua/config/keymaps.lua
map("n", "<leader>i", "", { desc = "+info" })
map("n", "<leader>if", "<cmd>LazyFormatInfo<cr>", { desc = "Format" })
map("n", "<leader>ic", "<cmd>ConformInfo<cr>", { desc = "Conform" })
map("n", "<leader>ir", "<cmd>LazyRoot<cr>", { desc = "Root" })
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
map("n", "<leader>iL", lint_info, { desc = "Lint" })
map("n", "<leader>iC", function()
  LazyVim.info(vim.g.colors_name, { title = "ColorScheme" })
end, { desc = "ColorScheme" })

-- navigate to line start and end from home row
-- -- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/keybindings.lua#L19
-- map({ "n", "x" }, "H", "0^", { desc = "Goto line start" }) -- scroll fully to the left
-- map("o", "H", "^", { desc = "Goto line start" })
-- map({ "n", "o" }, "L", "$", { desc = "Goto line end" })
-- -- https://github.com/v1nh1shungry/.dotfiles/blob/d8a0f6fd2766d0ec9ce5d5b4ccd55b3cc4130c1a/nvim/lua/dotfiles/core/keymaps.lua#L74
-- map("x", "L", "g_", { desc = "Goto line end" })
map({ "n", "x" }, "H", "&wrap ? 'g^' : '0^'", { desc = "Goto line start", expr = true }) -- scroll fully to the left
map("o", "H", "&wrap ? 'g^' : '^'", { desc = "Goto line start", expr = true })
map({ "n", "o" }, "L", "v:count ? '$' : &wrap ? 'g$' : '$'", { desc = "Goto line end", expr = true })
map("x", "L", "v:count ? 'g_' : &wrap ? 'g$' : 'g_'", { desc = "Goto line end", expr = true }) -- TODO: to the last non-blank character of the line when wrapped
-- https://github.com/folke/lazy.nvim/issues/411
-- https://github.com/folke/lazy.nvim/issues/133
LazyViewConfig.commands.home.key = "gH"
LazyViewConfig.commands.log.key = "gL"

-- quit
-- see: ../plugins/close.lua
-- map("n", "<bs>", "<cmd>q<cr>", { desc = "Quit" })
-- map("n", "<bs>", "<cmd>qa<cr>", { desc = "Quit All" })
-- map("n", "<bs>", LazyVim.ui.bufremove, { desc = "Delete Buffer" })
-- map("n", "<bs>", "<cmd>bd<cr>", { desc = "Delete Buffer and Window" })
-- map("n", "<bs>", "<cmd>wincmd q<cr>", { desc = "Close window" })

map_del({ "n", "x", "o" }, "n")
map_del({ "n", "x", "o" }, "N")

map_del("i", ",")
map_del("i", ".")
map_del("i", ";")

-- save file
map("n", "<leader>fs", "<cmd>w<cr><esc>", { desc = "Save File" })
-- save file without formatting
map("n", "<leader>fS", "<cmd>noautocmd w<cr>", { desc = "Save File Without Formatting" })
map({ "i", "x", "n", "s" }, "<a-s>", "<cmd>noautocmd w<cr><esc>", { desc = "Save File Without Formatting" })
map({ "i", "x", "n", "s" }, "<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

map("n", "<D-r>", vim.cmd.edit, { desc = "Reload File" })

-- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/keybindings.lua#L234
map("n", "<cr>", "gd", { desc = "Goto local Declaration" })
-- restore default behavior of `<cr>`, which is overridden by my mapping above
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "neo-tree-popup" },
  callback = function(event)
    map("n", "<cr>", "<cr>", { buffer = event.buf })
  end,
})
vim.api.nvim_create_autocmd("CmdWinEnter", {
  callback = function(event)
    map("n", "<cr>", "<cr>", { buffer = event.buf })
  end,
})

-- buffers
-- see: akinsho/bufferline.nvim in ~/.config/nvim/lua/plugins/ui.lua
-- if you change the order of buffers :bnext and :bprevious will not respect the custom ordering
LazyVim.safe_keymap_set("n", "<Down>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
LazyVim.safe_keymap_set("n", "<Up>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
LazyVim.safe_keymap_set("n", "J", "<cmd>bnext<cr>", { desc = "Next Buffer" })
LazyVim.safe_keymap_set("n", "K", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map({ "n", "x" }, "gj", "J", { desc = "Join Lines" })
map({ "n", "x" }, "gk", "K", { desc = "Keywordprg" }) -- not necessary
LazyViewConfig.keys.hover = "gk"
-- ":e #" doesn't work if the alternate buffer doesn't have a file name, while CTRL-^ still works then
map("n", { "<leader>`", "<leader>bb" }, "<C-^>", { desc = "Switch to Other Buffer" })
map("n", "<leader>bA", "<cmd>bufdo bd<cr>", { desc = "Delete All Buffers" })

-- jumping
-- map("n", ",", "<C-o>", { desc = "Go Back" })
-- map("n", ";", "<C-i>", { desc = "Go Forward" })
map("n", "<Left>", "<C-o>", { desc = "Go Back" })
map("n", "<Right>", "<C-i>", { desc = "Go Forward" })

if LazyVim.has("noice.nvim") then
  map("n", "<esc>", "<cmd>noh<bar>Noice dismiss<cr><esc>", { desc = "Escape and Clear hlsearch/notifications" })
end
-- -- https://github.com/gabs712/dotfiles/blob/d73212ee9c55bb9c4b6f88bf2175b349d59205a7/nvim/.config/nvim/lua/core/keymaps.lua#L2
-- map("n", "<esc>", function()
--   vim.cmd("nohlsearch")
--
--   -- dismiss notifications by nvim-notify or noice.nvim
--   local ok, notify = pcall(require, "notify")
--   if ok then
--     notify.dismiss({ silent = true, pending = true })
--   end
--
--   -- TODO: do not close zen mode (floating window)
--
--   -- -- close all floating windows
--   -- for _, win in ipairs(vim.api.nvim_list_wins()) do
--   --   if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
--   --     vim.api.nvim_win_close(win, false)
--   --   end
--   -- end
--
--   -- close current floating window
--   if vim.api.nvim_win_is_valid(0) and vim.api.nvim_win_get_config(0).relative ~= "" then
--     vim.api.nvim_win_close(0, false)
--   end
--
--   -- TODO: missing <esc>, is it necessary?
-- end, { desc = "Clear hlsearch/notifications and Close floating window" })

-- match
-- helix-style mappings | https://github.com/boltlessengineer/nvim/blob/607ee0c9412be67ba127a4d50ee722be578b5d9f/lua/config/keymaps.lua#L103
-- remap to matchit
map({ "n", "x", "o" }, "mm", "%", { desc = "Goto matching bracket", remap = true })

-- map("n", "U", "<C-r>", { desc = "Redo" })

-- floating terminal
-- stylua: ignore
map("n", "<leader>.", function() LazyVim.terminal(nil, { cwd = vim.fn.expand("%:p:h") }) end, { desc = "Terminal (Buffer Dir)" })

-- windows
-- https://github.com/gpakosz/.tmux/blob/9cf49731cd785b76cf792046feed0e8275457918/.tmux.conf#L74
map("n", "<leader>_", "<C-W>v", { desc = "Split Window Right", remap = true })

-- tabs
map_del("n", "<leader><tab>f")
map_del("n", "<leader><tab>l")
map_del("n", "<leader><tab>]")
map_del("n", "<leader><tab>[")
map("n", "<leader><tab>H", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map("n", "<leader><tab>L", "<cmd>tablast<cr>", { desc = "Last Tab" })
map("n", "]<tab>", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "[<tab>", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

local function is_empty_line()
  return vim.api.nvim_get_current_line():match("^%s*$")
end
-- deleting without yanking empty line
-- stylua: ignore start
map("n", "dd", function() return is_empty_line() and '"_dd' or "dd" end, { expr = true, desc = "Don't Yank Empty Line to Clipboard" })
map("n", "i",  function() return is_empty_line() and '"_cc' or "i" end,  { expr = true, desc = "Indented i on Empty Line" })
-- stylua: ignore end

-- Add empty lines before and after cursor line supporting dot-repeat
-- https://github.com/JulesNP/nvim/blob/36b04ae414b98e67a80f15d335c73744606a33d7/lua/keymaps.lua#L80
-- map("n", "gO", function() vim.cmd("normal! m`" .. vim.v.count .. vim.api.nvim_replace_termcodes("O<esc>``", true, true, true)) end, { desc = "Put empty line above" })
-- map("n", "go", function() vim.cmd("normal! m`" .. vim.v.count .. vim.api.nvim_replace_termcodes("o<esc>``", true, true, true)) end, { desc = "Put empty line below" })
-- https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/basics.lua#L579
local MiniBasics = {}
_G.MiniBasics = MiniBasics
MiniBasics.put_empty_line = function(put_above)
  -- This has a typical workflow for enabling dot-repeat:
  -- - On first call it sets `operatorfunc`, caches data, and calls
  --   `operatorfunc` on current cursor position.
  -- - On second call it performs task: puts `v:count1` empty lines
  --   above/below current line.
  if type(put_above) == "boolean" then
    vim.o.operatorfunc = "v:lua.MiniBasics.put_empty_line"
    MiniBasics.cache_empty_line = { put_above = put_above }
    return "g@l"
  end
  local target_line = vim.fn.line(".") - (MiniBasics.cache_empty_line.put_above and 1 or 0)
  vim.fn.append(target_line, vim.fn["repeat"]({ "" }, vim.v.count1))
end
-- NOTE: if you don't want to support dot-repeat, use this snippet:
-- ```
-- map('n', 'gO', "<Cmd>call append(line('.') - 1, repeat([''], v:count1))<CR>")
-- map('n', 'go', "<Cmd>call append(line('.'),     repeat([''], v:count1))<CR>")
-- ```
map("n", "gO", "v:lua.MiniBasics.put_empty_line(v:true)", { expr = true, desc = "Put empty line above" })
map("n", "go", "v:lua.MiniBasics.put_empty_line(v:false)", { expr = true, desc = "Put empty line below" })

-- Reselect latest changed, put, or yanked text
-- `[v`]
-- https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/basics.lua#L589
-- map("n", "gV", '"`[" . strpart(getregtype(), 0, 1) . "`]"', { expr = true, replace_keycodes = false, desc = "Visually select changed text" })
-- https://github.com/gregorias/coerce.nvim#tips--tricks
-- stylua: ignore
map("n", "gp", function() vim.api.nvim_feedkeys("`[" .. vim.fn.strpart(vim.fn.getregtype(), 0, 1) .. "`]", "n", false) end, { desc = "Reselect last put/yanked/changed text" })

-- Search inside visually highlighted text. Use `silent = false` for it to make effect immediately.
map("x", "g/", "<esc>/\\%V", { silent = false, desc = "Search inside visual selection" })

map("n", "g/", "q/G", { desc = "command-line window (forward search)" })
map("n", "g?", "q?G", { desc = "command-line window (backward search)" })
map({ "n", "x" }, "g:", "q:G", { desc = "command-line window (Ex command)" })

-- map("n", "<leader>.", "@:", { desc = "Repeat last command-line" })
map("n", "g.", "@:", { desc = "Repeat last command-line" })

-- works even with `spell=false`
map("n", "z.", "1z=", { desc = "Fix Spelling" })

-- https://github.com/rstacruz/vimfiles/blob/ee9a3e7e7f022059b6d012eff2e88c95ae24ff97/lua/config/keymaps.lua#L35
-- https://github.com/nvim-lualine/lualine.nvim/blob/b431d228b7bbcdaea818bdc3e25b8cdbe861f056/lua/lualine/components/filename.lua#L74
-- :let @+=expand('%:p:~')<cr>
-- <cmd>call setreg('+', expand('%:p:~'))<cr>
map("n", "<leader>fy", function()
  -- local path = vim.fn.expand("%:p:~")
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:~") or ""
  vim.fn.setreg("+", path)
  LazyVim.info(path, { title = "Copied Path" })
end, { desc = "Yank file absolute path" })

map("n", "<leader>fY", function()
  -- local path = vim.fn.expand("%:~:.")
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.") or ""
  vim.fn.setreg("+", path)
  LazyVim.info(path, { title = "Copied Relative Path" })
end, { desc = "Yank file relative path" })

-- map("n", "<leader>fY", function()
--   local name = vim.fn.expand("%:t")
--   vim.fn.setreg("+", name)
--   LazyVim.info(("Copied file name: `%s`"):format(name))
-- end, { desc = "Yank file name" })

-- toggle options
U.toggle.map("<leader>ul", U.toggle("number", { name = "Line Number" }))
U.toggle.map("<leader>ud", U.toggle.diagnostic_virtual_text)
U.toggle.map("<leader>uD", U.toggle.diagnostics)

-- local function google_search(input)
--   local query = input or vim.fn.expand("<cword>")
--   LazyUtil.open("https://www.google.com/search?q=" .. query)
-- end
-- -- conflict with "Buffer Local Keymaps (which-key)" defined in ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/editor.lua
-- -- map("n", "<leader>?", google_search, { desc = "Google Search Current Word" })
-- -- stylua: ignore
-- map("x", "<leader>?", function() google_search(U.get_visual_selection()) end, { desc = "Google Search" })

if vim.g.user_is_termux then
  -- stylua: ignore
  map({ "i", "c", "t" }, "<C-v>", function() vim.api.nvim_paste(vim.fn.getreg("+"), true, -1) end, { desc = "Paste" })
end

if vim.g.neovide then
  -- fix cmd-v for paste in insert, command, terminal (for fzf-lua) mode
  -- https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste
  -- map("c", "<D-v>", "<C-r>+")
  -- https://github.com/neovide/neovide/issues/1263#issuecomment-1972013043
  -- stylua: ignore
  map({ "i", "c", "t" }, "<D-v>", function() vim.api.nvim_paste(vim.fn.getreg("+"), true, -1) end, { desc = "Paste" })

  -- https://github.com/folke/zen-mode.nvim/blob/29b292bdc58b76a6c8f294c961a8bf92c5a6ebd6/lua/zen-mode/config.lua#L70
  local neovide_disable_animations = {
    neovide_animation_length = 0,
    neovide_cursor_animate_command_line = false,
    neovide_scroll_animation_length = 0,
    neovide_position_animation_length = 0,
    neovide_cursor_animation_length = 0,
    neovide_cursor_vfx_mode = "",
  }
  local neovide_state = {} ---@type table<string, any>
  U.toggle.map("<leader>ua", {
    name = "Mini/Neovide Animate",
    get = function()
      -- return not vim.g.minianimate_disable -- extras.ui.mini-animate might not enabled
      return vim.g.neovide_cursor_animate_command_line
    end,
    set = function(state)
      vim.g.minianimate_disable = not state
      -- https://github.com/folke/zen-mode.nvim/blob/29b292bdc58b76a6c8f294c961a8bf92c5a6ebd6/lua/zen-mode/plugins.lua#L130
      if state then
        for key, _ in pairs(neovide_disable_animations) do
          if neovide_state[key] then
            vim.g[key] = neovide_state[key]
          end
        end
      else
        for key, value in pairs(neovide_disable_animations) do
          neovide_state[key] = vim.g[key]
          vim.g[key] = value
        end
      end
    end,
  })
end
