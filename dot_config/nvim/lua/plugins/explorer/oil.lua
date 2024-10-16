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
      -- default_file_explorer = false, -- default value: true
      default_file_explorer = vim.g.user_default_explorer == "oil.nvim",
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
        -- ["~"] = {
        --   desc = "<cmd>edit $HOME<CR>",
        --   callback = function()
        --     require("oil").open(vim.env.HOME)
        --   end,
        -- },
        ["~"] = false,
        ["<C-h>"] = false,
        ["<C-l>"] = false,
        ["<C-s>"] = false,
        ["<leader>wv"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
        ["<leader>ws"] = {
          "actions.select",
          opts = { horizontal = true },
          desc = "Open the entry in a horizontal split",
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
        ["<leader>sr"] = {
          desc = "Search and Replace in Directory (Oil)",
          callback = function()
            U.explorer.grug_far(require("oil").get_current_dir())
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

      -- https://github.com/stevearc/oil.nvim/issues/300#issuecomment-1950541064
      -- https://github.com/stevearc/oil.nvim/issues/268#issuecomment-1880161152
      local has_ssh_arg = false
      for _, arg in ipairs(vim.fn.argv()) do
        if vim.startswith(arg, "oil-ssh://") then
          has_ssh_arg = true
          break
        end
      end
      if has_ssh_arg then
        require("lazy").load({ plugins = { plugin.name } })
      else
        U.explorer.load_on_directory(plugin.name)
      end
    end,
  },
}
