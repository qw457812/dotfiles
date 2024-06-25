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

  {
    "echasnovski/mini.operators",
    event = "VeryLazy",
    vscode = true,
    -- https://github.com/echasnovski/mini.operators/blob/76ac9104d9773927053ea4eb12fc78ccbb5be813/doc/mini-operators.txt#L131
    opts = {
      -- gr -> cr (LazyVim use `gr` for lsp references, `cr` for remote flash by default)
      replace = { prefix = "cr" }, -- Replace text with register
      -- gx -> cx
      exchange = { prefix = "cx" }, -- Exchange text regions
      -- gm
      multiply = { prefix = "gm" }, -- Multiply (duplicate) text
      -- g= -> ""
      evaluate = { prefix = "" }, -- Evaluate text and replace with output
      -- gs -> ""
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
      },
      window = {
        mappings = {
          ["-"] = "close_window", -- toggle neo-tree, see: ~/.config/nvim/lua/config/keymaps.lua
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
  },

  -- TODO unify the keybindings of https://github.com/vifm/vifm and neo-tree.nvim (or telescope-file-browser.nvim)
  -- https://www.lazyvim.org/plugins/editor#neo-treenvim
  -- https://github.com/craftzdog/dotfiles-public/blob/bf837d867b1aa153cbcb2e399413ec3bdcce112b/.config/nvim/lua/plugins/editor.lua#L58
}
