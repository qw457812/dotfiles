-- https://github.com/aimuzov/LazyVimx/blob/main/lua/lazyvimx/extras/ui/style/popups/rounded.lua
-- https://github.com/consoleaf/nvim-config/blob/ebcd80b5accbf7e2a5ae568c9c157a7a880411a8/lua/plugins/round.lua
return {
  {
    "folke/snacks.nvim",
    optional = true,
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      -- -- https://github.com/Nitestack/dotfiles/blob/506b895c45b8ed012a2cb0c35fe62058d8b6dbc4/config/private_dot_config/exact_nvim/lua/exact_plugins/snacks.lua#L9
      -- win = {
      --   border = "rounded",
      -- },
      -- zen = {
      --   win = {
      --     border = "none",
      --   },
      -- },
      terminal = {
        win = {
          border = "rounded",
        },
      },
    },
  },

  {
    "nvim-cmp",
    optional = true,
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")
      opts.window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      }
    end,
  },

  -- copied from: https://github.com/AstroNvim/astrocommunity/blob/6166e840d19b0f6665c8e02c76cba500fa4179b0/lua/astrocommunity/completion/blink-cmp/init.lua#L15
  {
    "Saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      completion = {
        menu = {
          border = "rounded",
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
        },
        documentation = {
          window = {
            border = "rounded",
            winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
          },
        },
      },
      signature = {
        window = {
          border = "rounded",
          winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        },
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = {
      diagnostics = {
        float = { border = "rounded" },
      },
    },
  },

  {
    "folke/noice.nvim",
    optional = true,
    opts = {
      presets = { lsp_doc_border = true },
      -- lsp = {
      --   documentation = {
      --     opts = { win_options = { winhighlight = "NormalFloat:Float" } },
      --   },
      -- },
    },
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      popup_border_style = "rounded",
      default_component_configs = {
        indent = {
          last_indent_marker = "╰",
        },
      },
    },
  },

  {
    "williamboman/mason.nvim",
    optional = true,
    opts = { ui = { border = "rounded" } },
  },

  {
    "rcarriga/nvim-dap-ui",
    optional = true,
    opts = { floating = { border = "rounded" } },
  },

  {
    "lewis6991/gitsigns.nvim",
    optional = true,
    opts = { preview_config = { border = "rounded" } },
  },

  {
    "Bekaboo/dropbar.nvim",
    optional = true,
    opts = {
      menu = {
        win_configs = {
          border = "rounded",
        },
      },
    },
  },

  {
    "potamides/pantran.nvim",
    optional = true,
    opts = {
      window = {
        window_config = {
          border = "rounded",
        },
      },
    },
  },

  {
    "akinsho/toggleterm.nvim",
    optional = true,
    opts = {
      float_opts = {
        border = "rounded",
      },
    },
  },

  {
    "echasnovski/mini.files",
    optional = true,
    opts = function()
      -- https://github.com/MariaSolOs/dotfiles/blob/ca5623259e415996f59c89d98a1db15ade205b44/.config/nvim/lua/plugins/minifiles.lua#L125
      vim.api.nvim_create_autocmd("User", {
        pattern = "MiniFilesWindowOpen",
        callback = function(args)
          vim.api.nvim_win_set_config(args.data.win_id, { border = "rounded" })
        end,
      })
    end,
  },

  {
    "nvchad/showkeys",
    optional = true,
    opts = {
      winopts = {
        border = "rounded",
      },
    },
  },
}
