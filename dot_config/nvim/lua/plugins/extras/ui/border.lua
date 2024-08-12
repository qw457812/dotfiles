-- https://github.com/aimuzov/LazyVimx/blob/main/lua/lazyvimx/extras/ui/style/popups/rounded.lua
-- https://github.com/consoleaf/nvim-config/blob/ebcd80b5accbf7e2a5ae568c9c157a7a880411a8/lua/plugins/round.lua
return {
  {
    "hrsh7th/nvim-cmp",
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

  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function()
      require("lspconfig.ui.windows").default_options.border = "rounded"
    end,
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
    "folke/which-key.nvim",
    optional = true,
    opts = {
      preset = "modern",
    },
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = {
      popup_border_style = "rounded",
      default_component_configs = {
        indent = {
          -- indent_marker = "│",
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
}
