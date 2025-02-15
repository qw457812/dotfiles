-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

---@param name string
---@param clear? boolean
---@return integer
local function lazyvim_augroup(name, clear)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = clear or false })
end

-- show cursor line only in active window
-- https://github.com/folke/dot/blob/master/nvim/lua/config/autocmds.lua
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
  callback = function()
    if vim.w.auto_cursorline then
      vim.wo.cursorline = true
      vim.w.auto_cursorline = nil
    end
  end,
})
vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
  callback = function()
    if vim.wo.cursorline then
      vim.w.auto_cursorline = true
      vim.wo.cursorline = false
    end
  end,
})

-- backups
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("better_backup", { clear = true }),
  callback = function(event)
    local file = vim.uv.fs_realpath(event.match) or event.match
    local backup = vim.fn.fnamemodify(file, ":p:~:h")
    backup = backup:gsub("[/\\]", "%%")
    vim.go.backupext = backup
  end,
})

-- vim.api.nvim_create_autocmd("QuickFixCmdPost", {
--   callback = function()
--     vim.cmd([[Trouble qflist open]])
--   end,
-- })

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = { "*.env", "*.env.*" },
  desc = "Disable diagnostics on .env files",
  group = vim.api.nvim_create_augroup("disable_diagnostics_on_env", {}),
  callback = function(event)
    -- https://github.com/LazyVim/LazyVim/blob/1e83b4f843f88678189df81b1c88a400c53abdbc/lua/lazyvim/plugins/extras/util/dot.lua#L44
    if vim.bo[event.buf].filetype == "sh" then
      vim.diagnostic.enable(false, { bufnr = event.buf })
    end
  end,
})

-- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/config/keybindings.lua#L288
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(event)
    vim.keymap.set("n", "dd", function()
      local qf_items = vim.fn.getqflist()
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      table.remove(qf_items, lnum)
      vim.fn.setqflist(qf_items, "r")
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    end, { buffer = event.buf, silent = true, desc = "Remove quickfix entry" })
  end,
})

-- make it easier to scroll man/help files when opened inline with `<leader>sM`, `<leader>sh`, `:h`
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("pager_nomodifiable", { clear = true }),
  callback = function(event)
    local buf = event.buf
    vim.defer_fn(function()
      -- note that /etc/hosts (vim.bo.readonly == true) can be changed with warning "Changing a readonly file", but files where vim.bo.modifiable == false can't
      if
        vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].modifiable == false
        and not U.keymap.buffer_local_mapping_exists(buf, "n", { "u", "d", "dd" }) -- `dd` mapped for quickfix
      then
        vim.b[buf].minianimate_disable = true
        -- vim.b[buf].snacks_scroll = false
        vim.keymap.set("n", "u", "<C-u>", { buffer = buf, silent = true, desc = "Scroll Up" })
        -- add `nowait = true` since we have a `dd` mapping defined in keymaps.lua
        vim.keymap.set("n", "d", "<C-d>", { buffer = buf, silent = true, desc = "Scroll Down", nowait = true })
      end
    end, 500)
  end,
})

-- disable LazyVim's auto command for wrap
local wrap_spell_opts = { group = lazyvim_augroup("wrap_spell"), event = "FileType" }
local wrap_spell_pattern = vim.tbl_map(function(autocmd)
  return autocmd.pattern
end, vim.api.nvim_get_autocmds(wrap_spell_opts))
-- https://github.com/LazyVim/LazyVim/issues/3692
-- alternative: vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_clear_autocmds(wrap_spell_opts)
-- create my own
vim.api.nvim_create_autocmd("FileType", {
  pattern = wrap_spell_pattern,
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- disable wrap for some filetypes
vim.api.nvim_create_autocmd("FileType", {
  -- pattern = vim.list_extend({
  --   "lazy",
  -- }, wrap_spell_pattern),
  pattern = {
    "lazy", -- Lazy Extras, alternative: https://github.com/aimuzov/LazyVimx/blob/00d45b2d746c36101b4cf1c5fe0b46d53cb6774a/lua/lazyvimx/extras/hacks/lazyvim-remove-extras-title.lua
  },
  callback = function()
    vim.defer_fn(function()
      vim.opt_local.wrap = false
    end, 100)
  end,
})

-- -- revert `lazyvim_close_with_q` auto command for help files that we're editing
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "help",
--   callback = function(event)
--     if vim.bo[event.buf].buftype ~= "help" then
--       vim.bo[event.buf].buflisted = true
--       pcall(vim.keymap.del, "n", "q", { buffer = event.buf })
--     end
--   end,
-- })
--
-- unlisted some filetypes (e.g. qf, checkhealth) in favor of bufferline.nvim
local close_with_q_pattern = vim.tbl_map(function(autocmd)
  return autocmd.pattern
end, vim.api.nvim_get_autocmds({ group = lazyvim_augroup("close_with_q"), event = "FileType" }))
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("buf_unlisted", { clear = true }),
  -- pattern = vim.tbl_filter(function(pattern)
  --   return pattern ~= "help"
  -- end, close_with_q_pattern),
  pattern = close_with_q_pattern,
  callback = function(event)
    -- don't unlisted help files that we're editing
    if vim.bo[event.buf].filetype == "help" and vim.bo[event.buf].buftype ~= "help" then
      return
    end
    vim.bo[event.buf].buflisted = false
  end,
})
-- unlisted command-line window
vim.api.nvim_create_autocmd("CmdWinEnter", {
  group = vim.api.nvim_create_augroup("buf_unlisted", { clear = false }),
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})
-- overwrite `lazyvim_close_with_q` auto command
-- copied from: https://github.com/AstroNvim/AstroNvim/blob/d771094986abced8c3ceae29a5a55585ecb0523a/lua/astronvim/plugins/_astrocore_autocmds.lua#L245
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = lazyvim_augroup("close_with_q", true),
  desc = "Make q close help, man, quickfix, dap floats",
  callback = function(args)
    -- Add cache for buffers that have already had mappings created
    if not vim.g.q_close_windows then
      vim.g.q_close_windows = {}
    end
    -- If the buffer has been checked already, skip
    if vim.g.q_close_windows[args.buf] then
      return
    end
    -- Mark the buffer as checked
    vim.g.q_close_windows[args.buf] = true
    -- Check to see if `q` is already mapped to the buffer (avoids overwriting)
    if U.keymap.buffer_local_mapping_exists(args.buf, "n", "q") then
      return
    end
    -- If there is no q mapping already and the buftype is a non-real file, create one
    if vim.tbl_contains({ "help", "nofile", "quickfix" }, vim.bo[args.buf].buftype) then
      vim.keymap.set("n", "q", "<Cmd>close<CR>", {
        desc = "Close window",
        buffer = args.buf,
        silent = true,
        nowait = true,
      })
    end
  end,
})
vim.api.nvim_create_autocmd("BufDelete", {
  group = lazyvim_augroup("close_with_q"),
  desc = "Clean up q_close_windows cache",
  callback = function(args)
    if vim.g.q_close_windows then
      vim.g.q_close_windows[args.buf] = nil
    end
  end,
})

-- copied from:
-- https://github.com/echasnovski/mini.nvim/blob/73bbcbfa7839c4b00a64965fb504f87461abefbd/lua/mini/misc.lua#L194
-- https://github.com/mrbeardad/nvim/blob/916d17211cc67d082ece6476bdfffe1a9fc41d22/lua/user/configs/autocmds.lua#L61
if vim.g.user_auto_root and not vim.o.autochdir then
  local function set_root(buf)
    local root = LazyVim.root.get({ normalize = true, buf = buf })
    if root ~= vim.uv.cwd() then
      vim.fn.chdir(root)
    end
  end

  local current_buf = 0
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("auto_root", {}),
    desc = "Find root and change current directory",
    callback = function(event)
      current_buf = event.buf
      if vim.bo[current_buf].buftype == "" then
        vim.defer_fn(function()
          set_root(current_buf)
        end, 100) -- wait till lazyvim_root_cache augroup clear cache
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("auto_root", { clear = false }),
    callback = function(event)
      if event.buf == current_buf then
        vim.defer_fn(function()
          set_root(current_buf)
        end, 100)
      end
    end,
  })
end

-- work-around for zsh-vi-mode/fish_vi_key_bindings auto insert
if vim.o.shell:find("zsh") or vim.o.shell:find("fish") then
  vim.api.nvim_create_autocmd("TermEnter", {
    group = vim.api.nvim_create_augroup("shell_vi_mode", {}),
    pattern = "term://*" .. vim.o.shell,
    desc = "Enter insert mode of zsh-vi-mode or fish_vi_key_bindings",
    callback = function(event)
      if vim.bo[event.buf].filetype ~= "snacks_terminal" then
        return
      end
      vim.schedule(function()
        -- powerlevel10k for zsh-vi-mode or starship for fish_vi_key_bindings
        if vim.api.nvim_get_current_line():match("^❮ .*") then
          -- use `a` instead of `i` to restore cursor position
          vim.api.nvim_feedkeys(vim.keycode("a"), "n", false)
        end
      end)
    end,
  })
end

-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = { "markdown" },
--   callback = function()
--     vim.opt_local.colorcolumn = "80"
--   end,
-- })
