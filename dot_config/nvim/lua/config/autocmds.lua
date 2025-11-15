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
-- https://github.com/folke/dot/blob/56d310467f3f962e506810b710a1562cee03b75e/nvim/lua/config/autocmds.lua#L2-L17
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

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("lazy_plugin_readonly", { clear = true }),
  pattern = require("lazy.core.config").options.root .. "/*",
  callback = function(ev)
    vim.bo[ev.buf].readonly = true
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = { ".env", ".env.*" },
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
        and not U.keymap.exists("n", { "u", "d", "dd" }, { buf = buf }) -- `dd` mapped for quickfix
      then
        vim.b[buf].minianimate_disable = true
        -- vim.b[buf].snacks_scroll = false
        vim.keymap.set({ "n", "x" }, "u", "<C-u>", { buffer = buf, silent = true, desc = "Scroll Up" })
        -- add `nowait = true` since we have a `dd` mapping defined in keymaps.lua
        vim.keymap.set({ "n", "x" }, "d", "<C-d>", { buffer = buf, silent = true, desc = "Scroll Down", nowait = true })
      end
    end, 500)
  end,
})

do
  -- disable LazyVim's auto command for wrap
  local wrap_spell_opts = { group = lazyvim_augroup("wrap_spell"), event = "FileType" }
  local wrap_spell_pattern = vim.tbl_map(function(autocmd)
    return autocmd.pattern
  end, vim.api.nvim_get_autocmds(wrap_spell_opts))
  -- alternative: vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
  vim.api.nvim_clear_autocmds(wrap_spell_opts)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = wrap_spell_pattern,
    callback = function()
      vim.opt_local.spell = true
    end,
  })

  -- disable wrap for some filetypes
  vim.api.nvim_create_autocmd("FileType", {
    pattern = {
      "lazy", -- Lazy Extras, alternative: https://github.com/aimuzov/LazyVimx/blob/00d45b2d746c36101b4cf1c5fe0b46d53cb6774a/lua/lazyvimx/extras/hacks/lazyvim-remove-extras-title.lua
    },
    callback = function(ev)
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == ev.buf and vim.bo[ev.buf].filetype == ev.match then
          vim.opt_local.wrap = false
        end
      end)
    end,
  })
end

-- unlisted some filetypes (e.g. qf, checkhealth) in favor of bufferline.nvim
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("buf_unlisted", { clear = true }),
  pattern = vim.tbl_map(function(autocmd)
    return autocmd.pattern
  end, vim.api.nvim_get_autocmds({ group = lazyvim_augroup("close_with_q"), event = "FileType" })),
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
    if U.keymap.exists("n", "q", { buf = args.buf }) then
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

-- auto open explorer if the window is too wide
if vim.g.user_explorer_auto_open and not vim.g.vscode then
  -- using `{ "BufReadPre", "BufNewFile", "BufWritePre" }` instead of `LazyVim.plugin.lazy_file_events`, see: https://github.com/LazyVim/LazyVim/pull/6053
  vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile", "BufWritePre" }, {
    group = vim.api.nvim_create_augroup("explorer_auto_open", { clear = true }),
    callback = function(ev)
      -- ref: https://github.com/folke/snacks.nvim/commit/756a791131304a9063ff8e3af52811efbcaef688
      if vim.v.vim_did_enter == 0 then
        return
      end
      -- TODO: Snacks.explorer
      if package.loaded["neo-tree"] then
        return true -- let WinResized event to handle the rest
      end
      if
        vim.g.user_explorer_auto_close
        or vim.bo[ev.buf].buftype ~= ""
        or vim.list_contains({ "gitcommit", "svn" }, vim.bo[ev.buf].filetype)
        or vim.list_contains({ "COMMIT_EDITMSG", "svn-commit.tmp" }, vim.fn.fnamemodify(ev.file, ":t"))
        or vim.t.user_diffview
      then
        return
      end
      vim.schedule(function()
        if
          not vim.g.user_explorer_visible
          and not U.is_edgy_win()
          and vim.api.nvim_win_get_width(0) - vim.g.user_explorer_width >= 120
        then
          U.explorer.open({ focus = false })
        end
      end)
    end,
  })
end

-- copied from:
-- https://github.com/nvim-mini/mini.nvim/blob/73bbcbfa7839c4b00a64965fb504f87461abefbd/lua/mini/misc.lua#L194
-- https://github.com/mrbeardad/nvim/blob/916d17211cc67d082ece6476bdfffe1a9fc41d22/lua/user/configs/autocmds.lua#L61
if vim.g.user_auto_root and not vim.o.autochdir then
  ---debounced to wait for lazyvim_root_cache augroup to clear cache
  ---@type fun(buf:integer)
  local cd_root = U.debounce_wrap(100, function(buf)
    if buf ~= vim.api.nvim_get_current_buf() or vim.bo[buf].buftype ~= "" then
      return
    end
    local root = LazyVim.root.get({ normalize = true, buf = buf })
    if root ~= vim.uv.cwd() then
      vim.fn.chdir(root)
    end
  end)

  local current_buf = 0
  local group = vim.api.nvim_create_augroup("auto_root", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      current_buf = ev.buf
      cd_root(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost" }, {
    group = group,
    callback = function(ev)
      if ev.buf == current_buf then
        cd_root(ev.buf)
      end
    end,
  })
end

---@class vim.var_accessor
---@field user_last_file? { buf: number, path: string, root: string }

-- set up vim.g.user_last_file
-- see also: https://github.com/folke/snacks.nvim/issues/2378#issuecomment-3474790578
do
  ---@param opts { buf: integer, cond?: fun():boolean }
  local function track_last_file(opts)
    local buf = opts.buf
    -- debounced to wait for lazyvim_root_cache augroup to clear cache
    U.debounce("track-last-file", 30, function()
      if opts.cond and not opts.cond() then
        return
      end
      local _, file = U.is_file({ buf = buf })
      if not file then
        return
      end

      vim.g.user_last_file = {
        buf = buf,
        path = file,
        root = LazyVim.root.get({ normalize = true, buf = buf }),
      }
    end)
  end

  local current_buf = 0
  local group = vim.api.nvim_create_augroup("track_last_file", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      current_buf = ev.buf
      track_last_file({ buf = ev.buf })
    end,
  })
  vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost" }, {
    group = group,
    callback = function(ev)
      if ev.buf == current_buf then
        track_last_file({
          buf = ev.buf,
          -- only update root/path for already-tracked buffer
          cond = function()
            return ev.buf == (vim.g.user_last_file or {}).buf
          end,
        })
      end
    end,
  })
end
