-- TODO: see LazyVim.lsp.on_rename in:
-- - ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/editor.lua
-- - ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/mini-files.lua
return {
  -- https://github.com/stevearc/dotfiles/blob/eeb506f9afd32cd8cd9f2366110c76efaae5786c/.config/nvim/lua/plugins/oil.lua
  -- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/oil.lua
  -- https://github.com/kevinm6/nvim/blob/0c2d0fcb04be1f0837ae8918b46131f649cba775/lua/plugins/editor/oil.lua
  -- https://github.com/jellydn/lazy-nvim-ide/blob/main/lua/plugins/extras/oil.lua
  {
    "stevearc/oil.nvim",
    dependencies = { "echasnovski/mini.icons", optional = true },
    opts = {
      -- whether to use for editing directories (e.g. `vim .` or `:e src/`)
      -- disabled because neo-tree is used for that
      default_file_explorer = false, -- default value: true
      delete_to_trash = true,
      -- skip_confirm_for_simple_edits = true,
      -- prompt_save_on_select_new_entry = false,
      -- watch_for_changes = true,
      float = {
        max_height = 30, -- 30 ~ 45
        max_width = 100, -- 90 ~ 120
      },
      keymaps = {
        ["q"] = "actions.close", -- for floating window
        -- ["`"] = "actions.tcd",
        ["~"] = {
          desc = "<cmd>edit $HOME<CR>",
          callback = function()
            require("oil").open(vim.env.HOME)
          end,
        },
        ["<leader>."] = {
          desc = "Terminal (Oil Dir)",
          callback = function()
            LazyVim.terminal(nil, { cwd = require("oil").get_current_dir() })
          end,
        },
        ["gd"] = {
          desc = "Toggle detail view",
          callback = function()
            local oil = require("oil")
            local config = require("oil.config")
            if #config.columns == 1 then
              oil.set_columns({ "icon", "permissions", "size", "mtime" })
            else
              oil.set_columns({ "icon" })
            end
          end,
        },
      },
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name, bufnr)
          return name == ".."
        end,
      },
    },
    keys = function()
      -- stylua: ignore
      local keys = {
        --[[add custom keys here]]
        -- { "<leader><cr>", function() require("oil").toggle_float() end, desc = "Toggle Float Oil" },
      }

      local opts = LazyVim.opts("oil.nvim")
      if opts.default_file_explorer == nil or opts.default_file_explorer == true then
        -- stylua: ignore
        vim.list_extend(keys, {
          { "-", function() require("oil").open() end, desc = "Open parent directory (Oil)" },
          { "_", function() require("oil").open(vim.fn.getcwd()) end, desc = "Open cwd (Oil)" },
        })
      else
        -- stylua: ignore
        vim.list_extend(keys, {
          -- { "_", function() require("oil").open() end, desc = "Open parent directory (Oil)" },
          { "_", function() require("oil").toggle_float() end, desc = "Toggle Float Oil" },
        })
      end
      return keys
    end,
    init = function(plugin)
      local opts = LazyVim.opts("oil.nvim")
      if opts.default_file_explorer == false then
        return
      end

      -- make oil handle `nvim .` correctly (bad alternative: `lazy = false`)
      -- https://github.com/stevearc/oil.nvim/issues/300#issuecomment-1950541064
      -- https://github.com/stevearc/oil.nvim/issues/268#issuecomment-1880161152
      if vim.fn.argc() == 1 then
        local argv = tostring(vim.fn.argv(0))
        local stat = vim.uv.fs_stat(argv)

        local remote_dir_args = vim.startswith(argv, "ssh")
          or vim.startswith(argv, "sftp")
          or vim.startswith(argv, "scp")

        if stat and stat.type == "directory" or remote_dir_args then
          require("lazy").load({ plugins = { plugin.name } })
        end
      end
      if not require("lazy.core.config").plugins[plugin.name]._.loaded then
        vim.api.nvim_create_autocmd("BufNew", {
          callback = function()
            if vim.fn.isdirectory(vim.fn.expand("<afile>")) == 1 then
              require("lazy").load({ plugins = { "oil.nvim" } })
              -- once oil is loaded, we can delete this autocmd
              return true
            end
          end,
        })
      end
    end,
  },
}
