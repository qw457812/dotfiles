-- close buffers, windows, or exit vim with the same single keypress
local close_key = "<bs>"

-- TODO: Map `<leader><bs>` to `:qa`? Used by which-key.

-- close some filetypes with close_key
-- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/autocmds.lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    -- close_with_q by LazyVim
    "PlenaryTestPopup",
    "grug-far",
    "help",
    "lspinfo",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
    "dbout",
    "gitsigns.blame",
    -- close_key only
    "lazy",
    "mason",
    "Trans", -- JuanZoran/Trans.nvim
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", close_key, "<cmd>close<cr>", {
      buffer = event.buf,
      silent = true,
      desc = "Quit buffer",
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "dashboard", -- NOTE: not working in ../config/autocmds.lua, but works here or `opts` function of Lazy Plugin Spec
    "leetcode.nvim", -- kawre/leetcode.nvim
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", close_key, "<cmd>qa<cr>", {
      buffer = event.buf,
      silent = true,
      desc = "Quit",
    })
  end,
})

if vim.g.vscode then
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyVimKeymaps",
    callback = function()
      vim.keymap.set("n", "<bs>", [[<cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<cr>]])
    end,
  })
end

return {
  -- TODO: see LazyVim.ui.bufremove
  {
    "psjay/buffer-closer.nvim",
    keys = {
      { close_key, desc = "Close buffer/window or Exit" },
    },
    opts = {
      close_key = close_key,
    },
  },

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
    "stevearc/oil.nvim",
    optional = true,
    opts = {
      keymaps = {
        [close_key] = "actions.close",
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

  -- TODO: lazygit
}
