-- close buffers, windows, or exit vim with the same single keypress
local close_key = "<bs>" -- easy to reach for Glove80
-- exit nvim
local exit_key = "<leader>" .. close_key -- NOTE: would overwrite "go up one level" of which-key, use `<S-bs>`?

local augroup = vim.api.nvim_create_augroup("close_with_" .. close_key, { clear = true })

-- alternative to psjay/buffer-closer.nvim
-- copied from: https://github.com/psjay/buffer-closer.nvim/blob/74fec63c4c238b2cf6f61c40b47f869d442a8988/lua/buffer-closer/init.lua#L10
-- https://github.com/chrisgrieser/.config/blob/88eb71f88528f1b5a20b66fd3dfc1f7bd42b408a/nvim/lua/funcs/alt-alt.lua#L42
local function close_buffer_or_window_or_exit()
  if vim.g.vscode then
    local vscode = require("vscode")
    vscode.call("workbench.action.unpinEditor")
    vscode.action("workbench.action.closeActiveEditor") -- can not close pinned editor
    return
  end

  local function listed_buffers()
    -- return vim.fn.getbufinfo({ buflisted = 1 })
    return vim.tbl_filter(function(b)
      return vim.bo[b].buflisted and vim.api.nvim_buf_is_valid(b)
    end, vim.api.nvim_list_bufs())
  end

  ---https://github.com/nvim-neo-tree/neo-tree.nvim/blob/206241e451c12f78969ff5ae53af45616ffc9b72/lua/neo-tree/sources/manager.lua#L141
  ---https://github.com/echasnovski/mini.nvim/blob/af673d8523c5c2c5ff0a53b1e42a296ca358dcc7/lua/mini/animate.lua#L1397
  ---@param win number?
  local function is_floating(win)
    return vim.api.nvim_win_get_config(win or 0).relative ~= ""
  end

  -- the buftype is a non-real file
  -- https://github.com/AstroNvim/AstroNvim/blob/d771094986abced8c3ceae29a5a55585ecb0523a/lua/astronvim/plugins/_astrocore_autocmds.lua#L245
  local function non_real_file()
    -- return vim.bo.buftype ~= ""
    return vim.tbl_contains({ "help", "nofile", "quickfix" }, vim.bo.buftype)
  end

  -- known window types: main, floating and edgy
  -- use `:close` for floating and edgy (redundant with edgy's Lazy Spec below)
  -- use `:bd` (or `:qa` if no listed buffer left) for main
  -- https://github.com/folke/edgy.nvim/blob/ebb77fde6f5cb2745431c6c0fe57024f66471728/lua/edgy/editor.lua#L82
  -- https://github.com/mudox/neovim-config/blob/a4f1020213fd17e6b8c1804153b9bf7683bfa690/lua/mudox/lab/close.lua#L7
  if is_floating() then
    vim.cmd("close") -- Close Window (Cannot close last window)
  elseif #listed_buffers() > (vim.bo.buflisted and 1 or 0) then
    if non_real_file() then
      vim.cmd("bd") -- Delete Buffer and Window
    else
      LazyVim.ui.bufremove() -- Delete Buffer
    end
  else
    vim.cmd("qa")
  end
end

vim.api.nvim_create_autocmd("User", {
  group = augroup,
  pattern = "LazyVimKeymaps",
  once = true,
  callback = function()
    vim.keymap.set("n", close_key, close_buffer_or_window_or_exit, { desc = "Close buffer/window or Exit" })
    vim.keymap.set("n", exit_key, "<cmd>qa<cr>", { desc = "Quit All" })
    if close_key:lower() == "<bs>" then
      vim.keymap.set("c", close_key, function()
        if vim.fn.getcmdline() ~= "" then
          return close_key
        end
      end, { expr = true, desc = "<bs> does not leave cmdline" })
    end
  end,
})

-- close some filetypes with close_key
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = {
    "Avante",
    "AvanteInput",
  },
  callback = function(event)
    vim.keymap.set("n", close_key, "<cmd>close<cr>", {
      buffer = event.buf,
      silent = true,
      desc = "Quit buffer",
    })
  end,
})

-- see: `:h q:`
vim.api.nvim_create_autocmd("CmdWinEnter", {
  group = augroup,
  callback = function(event)
    vim.keymap.set("n", close_key, "<cmd>q<cr>", {
      buffer = event.buf,
      silent = true,
      desc = "Close command-line window",
    })
  end,
})

if close_key:lower() == "<bs>" then
  vim.api.nvim_create_autocmd("TermOpen", {
    group = augroup,
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
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      local defaults_views = require("noice.config.views").defaults
      opts.views = vim.tbl_deep_extend("force", {
        split = {
          close = {
            keys = vim.deepcopy(defaults_views.split.close.keys),
          },
        },
        popup = {
          close = {
            keys = vim.deepcopy(defaults_views.popup.close.keys),
          },
        },
      }, opts.views or {})

      table.insert(opts.views.split.close.keys, close_key)
      table.insert(opts.views.popup.close.keys, close_key)
    end,
  },

  {
    "folke/trouble.nvim",
    optional = true,
    opts = {
      keys = {
        [close_key] = "close",
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
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
          local buf_id = args.data.buf_id
          -- stylua: ignore
          vim.keymap.set("n", close_key, function() require("mini.files").close() end, { buffer = buf_id, desc = "Close (mini.files)" })
        end,
      })

      opts.mappings = opts.mappings or {}
      if not opts.mappings.reset or opts.mappings.reset:lower() == close_key:lower() then
        opts.mappings.reset = ""
      end
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

  {
    "oysandvik94/curl.nvim",
    optional = true,
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "curl",
        callback = function(event)
          vim.keymap.set("n", close_key, "<cmd>CurlClose<cr>", {
            buffer = event.buf,
            silent = true,
            desc = "Close (curl.nvim)",
          })
        end,
      })
    end,
  },

  {
    "potamides/pantran.nvim",
    optional = true,
    opts = function(_, opts)
      local actions = require("pantran.ui.actions")

      opts.controls = vim.tbl_deep_extend("force", {
        mappings = {
          edit = {
            n = {
              [close_key] = actions.close,
            },
          },
        },
      }, opts.controls or {})
    end,
  },
}
