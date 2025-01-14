if false then
  -- Enable to autoload session on startup, unless:
  -- * neovim was started with files as arguments
  -- * stdin has been provided
  -- * git commit/rebase session
  vim.g.user_auto_session = false
end

return {
  -- copied from: https://github.com/rafi/vim-config/blob/0feb5daebc9f5297f01dc2304f81156318b8616b/lua/rafi/plugins/editor.lua#L27
  {
    "folke/persistence.nvim",
    optional = true,
    opts = {
      branch = false,
    },
    init = function()
      -- detect if stdin has been provided
      vim.g.user_from_stdin = false
      vim.api.nvim_create_autocmd("StdinReadPre", {
        group = vim.api.nvim_create_augroup("auto_session", {}),
        callback = function()
          vim.g.user_from_stdin = true
        end,
      })
      -- autoload session on startup
      vim.api.nvim_create_autocmd("VimEnter", {
        group = "auto_session",
        once = true,
        nested = true,
        callback = function()
          if not vim.g.user_auto_session then
            return
          end
          local cwd = vim.uv.cwd() or vim.fn.getcwd()
          if not cwd or vim.fn.argc() > 0 or vim.g.user_from_stdin or vim.env.GIT_EXEC_PATH then
            require("persistence").stop()
            return
          end
          local ignored_dirs = { vim.env.TMPDIR or "/tmp", "/private/tmp" }
          for _, path in ipairs(ignored_dirs) do
            if cwd:sub(1, #path) == path then
              require("persistence").stop()
              return
            end
          end
          -- close all floats before loading a session (e.g. lazy.nvim)
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_config(win).zindex then
              vim.api.nvim_win_close(win, false)
            end
          end
          require("persistence").load({ last = vim.g.user_auto_root })
        end,
      })
    end,
  },

  -- {
  --   "akinsho/bufferline.nvim",
  --   optional = true,
  --   opts = {
  --     options = {
  --       -- https://github.com/rafi/vim-config/blob/0feb5daebc9f5297f01dc2304f81156318b8616b/lua/rafi/plugins/ui.lua#L72
  --       custom_areas = vim.g.user_auto_session
  --           and not vim.g.user_is_termux
  --           and {
  --             right = function()
  --               local result = {}
  --               local root = LazyVim.root({ normalize = true })
  --               table.insert(result, {
  --                 text = " " .. require("bufferline.utils").truncate_name(vim.fn.fnamemodify(root, ":t"), 18) .. " ",
  --                 link = "BufferLineTab",
  --               })
  --
  --               -- session indicator
  --               if vim.v.this_session ~= "" then
  --                 table.insert(result, { text = " ", link = "BufferLineTab" })
  --               end
  --               return result
  --             end,
  --           }
  --         or nil,
  --     },
  --   },
  -- },
}
