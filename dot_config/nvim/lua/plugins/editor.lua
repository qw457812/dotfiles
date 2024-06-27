return {
  -- for escaping easily from insert mode
  {
    "max397574/better-escape.nvim",
    event = "InsertCharPre",
    opts = {
      mapping = { "jk", "jj", "kj", "kk" },
      timeout = 300,
    },
  },

  -- TODO fix `crr`: unbind `r` for remote flash
  {
    "echasnovski/mini.operators",
    event = "VeryLazy",
    vscode = true,
    -- https://github.com/echasnovski/mini.operators/blob/76ac9104d9773927053ea4eb12fc78ccbb5be813/doc/mini-operators.txt#L131
    opts = {
      -- gr (LazyVim use `gr` for lsp references, `cr` for remote flash by default)
      replace = { prefix = "cr" }, -- Replace text with register
      -- gx
      exchange = { prefix = "cx" }, -- Exchange text regions
      -- gm
      multiply = { prefix = "gm" }, -- Multiply (duplicate) text
      -- g=
      evaluate = { prefix = "" }, -- Evaluate text and replace with output
      -- gs
      sort = { prefix = "" }, -- Sort text
    },
  },

  -- https://github.com/doctorfree/nvim-lazyman/blob/bb4091c962e646c5eb00a50eca4a86a2d43bcb7c/lua/ecovim/config/plugins.lua#L373
  {
    "folke/flash.nvim",
    -- stylua: ignore
    keys = {
      -- r -> <space> (since `cr` is used for replace with register in mini.operators)
      -- https://github.com/rileyshahar/dotfiles/blob/ce20b2ea474f20e4eb7493e84c282645e91a36aa/nvim/lua/plugins/movement.lua#L99
      { "<space>", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    },
  },

  -- https://github.com/liubang/nvimrc/blob/e7dbb3f5193728b59dbfff5dcd5b3756c5ed1585/lua/plugins/neo-tree-nvim.lua
  -- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/neo-tree-extended.lua
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
          hide_by_name = {
            "node_modules",
            ".git",
          },
          never_show = {
            ".DS_Store",
            "thumbs.db",
          },
        },
        -- do not use neo-tree to `vim .` or `:e src/`
        hijack_netrw_behavior = "disabled", -- netrw left alone, neo-tree does not handle opening dirs
      },
      window = {
        mappings = {
          -- ["-"] = "close_window", -- toggle neo-tree, see keys bleow
          ["<bs>"] = "none", -- quit, see: ~/.config/nvim/lua/config/keymaps.lua
          -- TODO h close_node or navigate_up
          -- https://github.com/GentleCold/dotfiles/blob/5104ac8fae45b68a33c973a19b1f6a2e0617d400/.config/nvim/lua/plugins/dir_tree.lua
          ["h"] = "navigate_up",
          -- TODO l set_root?
        },
      },
      buffers = {
        window = {
          mappings = {
            ["bd"] = "none", -- use `d` instead
            ["d"] = "buffer_delete",
          },
        },
      },
      event_handlers = {
        -- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#auto-close-on-open-file
        -- alternative: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/344
        {
          event = "file_opened",
          handler = function(file_path)
            -- auto close
            require("neo-tree.command").execute({ action = "close" })
          end,
        },
      },
    },
    keys = {
      -- -- make the `-` key reveal the current file, or if in an unsaved file, the current working directory
      -- -- :h neo-tree-configuration
      -- {
      --   "-",
      --   function()
      --     local reveal_file = vim.fn.expand("%:p")
      --     if reveal_file == "" then
      --       reveal_file = vim.fn.getcwd()
      --     else
      --       local f = io.open(reveal_file, "r")
      --       if f then
      --         f.close(f)
      --       else
      --         reveal_file = vim.fn.getcwd()
      --       end
      --     end
      --     require("neo-tree.command").execute({
      --       action = "focus", -- OPTIONAL, this is the default value
      --       source = "filesystem", -- OPTIONAL, this is the default value
      --       position = "left", -- OPTIONAL, this is the default value
      --       reveal_file = reveal_file, -- path to file or folder to reveal
      --       reveal_force_cwd = true, -- change cwd without asking if needed
      --     })
      --   end,
      --   desc = "Open neo-tree at current file or working directory",
      -- },
    },
  },

  -- https://github.com/stevearc/dotfiles/blob/eeb506f9afd32cd8cd9f2366110c76efaae5786c/.config/nvim/lua/plugins/oil.lua
  -- https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/editor/oil.lua
  -- https://github.com/kevinm6/nvim/blob/0c2d0fcb04be1f0837ae8918b46131f649cba775/lua/plugins/editor/oil.lua
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      -- oil will take over directory buffers (e.g. `vim .` or `:e src/`)
      -- set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
      default_file_explorer = true,
      delete_to_trash = true,
      -- skip_confirm_for_simple_edits = true,
      -- prompt_save_on_select_new_entry = false,
      -- experimental_watch_for_changes = true,
      float = {
        max_height = 45,
        max_width = 90,
      },
      keymaps = {
        ["q"] = "actions.close",
        -- ["`"] = "actions.tcd",
        ["~"] = "<cmd>edit $HOME<CR>",
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
      -- view_options = {
      --   is_always_hidden = function(name, bufnr)
      --     return name == ".."
      --   end,
      -- },
    },
    -- stylua: ignore
    keys = {
      { "<leader><cr>", function() require("oil").toggle_float() end, desc = "Toggle Float Oil" },
      { "-", function() require("oil").open() end, desc = "Open parent directory (Oil)" },
      { "_", function() require("oil").open(vim.fn.getcwd()) end, desc = "Open cwd (Oil)" },
    },
    -- lazy = false, -- a bad way to make oil handle `nvim .`
    -- https://github.com/stevearc/oil.nvim/issues/300#issuecomment-1950541064
    -- https://github.com/stevearc/oil.nvim/issues/268#issuecomment-1880161152
    init = function(plugin)
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

  -- TODO unify the keybindings of https://github.com/vifm/vifm and neo-tree.nvim (or telescope-file-browser.nvim)
  -- https://www.lazyvim.org/plugins/editor#neo-treenvim
  -- https://github.com/craftzdog/dotfiles-public/blob/bf837d867b1aa153cbcb2e399413ec3bdcce112b/.config/nvim/lua/plugins/editor.lua#L58
}
