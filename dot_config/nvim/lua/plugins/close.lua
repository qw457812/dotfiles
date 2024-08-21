-- close buffers, windows, or exit vim with the same single keypress
local close_key = "<bs>" -- easy to reach for Glove80
-- exit nvim
local exit_key = "<leader>" .. close_key -- NOTE: would overwrite "go up one level" of which-key

-- alternative to psjay/buffer-closer.nvim
-- copied from: https://github.com/psjay/buffer-closer.nvim/blob/74fec63c4c238b2cf6f61c40b47f869d442a8988/lua/buffer-closer/init.lua#L10
local function close_buffer_or_window_or_exit()
  if vim.g.vscode then
    vim.cmd([[call VSCodeNotify('workbench.action.closeActiveEditor')]])
    return
  end

  local function listed_buffers()
    return vim.tbl_filter(function(b)
      return vim.bo[b].buflisted and vim.api.nvim_buf_is_valid(b)
    end, vim.api.nvim_list_bufs())
  end

  ---https://github.com/folke/which-key.nvim/blob/6c1584eb76b55629702716995cca4ae2798a9cca/lua/which-key/extras.lua#L53
  ---https://github.com/nvim-neo-tree/neo-tree.nvim/blob/206241e451c12f78969ff5ae53af45616ffc9b72/lua/neo-tree/sources/manager.lua#L141
  ---@param win number?
  local function is_window_floating(win)
    return vim.api.nvim_win_get_config(win or 0).relative ~= ""
  end

  -- not edgy and valid and not floating
  -- https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/animate.lua#L1397
  local function normal_windows()
    local edgy_wins = LazyVim.has("edgy.nvim") and require("edgy.editor").list_wins().edgy or {}
    return vim.tbl_filter(function(w)
      return not edgy_wins[w] and vim.api.nvim_win_is_valid(w) and not is_window_floating(w)
    end, vim.api.nvim_list_wins())
  end

  -- 1. For floating windows
  if is_window_floating() then
    -- eg. open lazy (non-listed) via dashboard (non-listed)
    vim.cmd("close")
    return
  end

  if vim.bo.buflisted then
    -- 2. For listed buffers
    if #listed_buffers() > 1 then
      -- vim.cmd("bd") -- Delete Buffer and Window
      LazyVim.ui.bufremove() -- Delete Buffer
    else
      vim.cmd("qa")
    end
  else
    -- 3. For non-listed buffers, including:
    --    - some filetypes maintained by `close_with_q` autocmd-groups, see: ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/autocmds.lua
    --    - manpages, see: https://github.com/LazyVim/LazyVim/blob/12818a6cb499456f4903c5d8e68af43753ebc869/lua/lazyvim/config/autocmds.lua#L84
    --    - dashboard, leetcode.nvim
    --    - others: lazy, mason, LazyVim.news.changelog(), JuanZoran/Trans.nvim, ...
    local normal_wins = normal_windows()
    -- https://github.com/mudox/neovim-config/blob/a4f1020213fd17e6b8c1804153b9bf7683bfa690/lua/mudox/lab/close.lua#L7
    if #normal_wins > 1 or not vim.list_contains(normal_wins, vim.api.nvim_get_current_win()) then
      -- eg. edgy windows
      vim.cmd("close") -- Close Window (Cannot close last window)
    elseif #listed_buffers() > 0 then
      -- eg. open manpage file directly while having other listed buffers
      vim.cmd("bd")
    else
      -- eg. dashboard or open a single manpage file directly
      vim.cmd("qa")
    end
  end
end

vim.api.nvim_create_autocmd("User", {
  pattern = "LazyVimKeymaps",
  callback = function()
    vim.keymap.set("n", close_key, close_buffer_or_window_or_exit, { desc = "Close buffer/window or Exit" })
    vim.keymap.set("n", exit_key, "<cmd>qa<cr>", { desc = "Quit All" })
  end,
})

-- see: `:h q:`
vim.api.nvim_create_autocmd("CmdWinEnter", {
  callback = function(event)
    vim.keymap.set("n", close_key, "<cmd>q<cr>", {
      buffer = event.buf,
      silent = true,
      desc = "Close command-line window",
    })
  end,
})

if close_key == "<bs>" then
  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "*lazygit",
    callback = function(event)
      -- mapped <c-h> to quit in lazygit/config.yml via `quitWithoutChangingDirectory: <backspace>`
      -- when typing a commit message in lazygit, <c-h> and <bs> do the same thing
      vim.keymap.set("t", close_key, "<C-h>", {
        buffer = event.buf,
        silent = true,
        desc = "Quit Lazygit",
      })
    end,
  })
end

return {
  {
    "folke/edgy.nvim",
    optional = true,
    opts = {
      keys = {
        [close_key] = function(win)
          win:close()
        end,
      },
    },
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      window = {
        mappings = {
          [close_key] = "close_window",
        },
      },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    opts = {
      defaults = {
        mappings = {
          n = {
            [close_key] = "close",
          },
        },
      },
    },
  },

  {
    "stevearc/oil.nvim",
    optional = true,
    opts = {
      keymaps = {
        [close_key] = "actions.close",
      },
    },
  },

  {
    "echasnovski/mini.files",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
          local buf_id = args.data.buf_id
          -- stylua: ignore
          vim.keymap.set("n", close_key, function() require("mini.files").close() end, { buffer = buf_id, desc = "Close (mini.files)" })
        end,
      })
    end,
  },

  {
    "Bekaboo/dropbar.nvim",
    optional = true,
    opts = {
      menu = {
        keymaps = {
          [close_key] = function()
            local menu = require("dropbar.utils.menu").get_current()
            while menu and menu.prev_menu do
              menu = menu.prev_menu
            end
            if menu then
              menu:close()
            end
          end,
        },
      },
    },
  },
}
