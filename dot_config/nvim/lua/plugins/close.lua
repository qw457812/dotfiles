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
  local function is_floating(win)
    return vim.api.nvim_win_get_config(win or 0).relative ~= ""
  end

  ---@param win number?
  local function is_edgy(win)
    if not LazyVim.has("edgy.nvim") then
      return false
    end
    win = win or 0
    win = win == 0 and vim.api.nvim_get_current_win() or win
    local edgy_wins = require("edgy.editor").list_wins().edgy
    return vim.tbl_contains(edgy_wins, win)
  end

  -- known window types: main, floating and edgy | https://github.com/folke/edgy.nvim/blob/ebb77fde6f5cb2745431c6c0fe57024f66471728/lua/edgy/editor.lua#L82
  -- use `:close` for floating and edgy (redundant with edgy's Lazy Spec below)
  -- use `:bd` or `:qa` for main
  if
    is_floating() -- eg. open lazy (non-listed) via dashboard (non-listed)
    -- or is_edgy() -- using Lazy Spec below
  then
    vim.cmd("close")
  elseif #listed_buffers() > (vim.bo.buflisted and 1 or 0) then
    -- vim.cmd("bd") -- Delete Buffer and Window
    LazyVim.ui.bufremove() -- Delete Buffer
  else
    vim.cmd("qa")
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
