local overrides = require("custom.configs.overrides")

---@type NvPluginSpec[]
local plugins = {

  -- Override plugin definition options

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- format & linting
      {
        "jose-elias-alvarez/null-ls.nvim",
        config = function()
          require "custom.configs.null-ls"
        end,
      },
    },
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end, -- Override to setup mason-lspconfig
  },

  -- override plugin configs
  {
    "williamboman/mason.nvim",
    opts = overrides.mason
  },

  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   opts = overrides.treesitter,
  -- },
  -- my | https://nvchad.com/docs/config/syntax
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- defaults 
        "vim",
        "lua",
        "vimdoc",

        "java",
        "scala",
        "python",
        "sql",
        "clojure",
        "bash",

        -- web dev 
        "html",
        "css",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "xml",
        "yaml",
        -- "vue", "svelte",

       -- low level
        "c",
        "zig"
      },
      -- https://github.com/nvim-treesitter/nvim-treesitter#modules
      -- Automatically install missing parsers when entering buffer
      -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
      auto_install = true,
    },
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = overrides.nvimtree,
  },

  -- Install a plugin
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      -- my
      -- require("better_escape").setup()
      require("better_escape").setup {
        mapping = { "jk", "jj", "kj" }, -- a table with mappings to use
        timeout = vim.o.timeoutlen,     -- the time in which the keys must be hit in ms. Use option timeoutlen by default
        clear_empty_lines = false,      -- clear line after escaping if there is only whitespace
        keys = "<Esc>",                 -- keys used for escaping, if it is a function will use the result everytime
      }
    end,
  },

  -- To make a plugin not be loaded
  -- {
  --   "NvChad/nvim-colorizer.lua",
  --   enabled = false
  -- },

  -- my
  {
    -- https://www.lunarvim.org/docs/configuration/plugins/example-configurations
    "phaazon/hop.nvim",
    event = "BufRead",
    config = function()
      require("hop").setup()
      -- vim.api.nvim_set_keymap("n", "s", ":HopChar2<cr>", { silent = true })
      -- vim.api.nvim_set_keymap("n", "S", ":HopWord<cr>", { silent = true })
      vim.api.nvim_set_keymap("n", "<leader>,", ":HopWord<cr>", { silent = true })
    end,
  },
  {
    "ggandor/leap.nvim",
    name = "leap",
    event = "BufRead",
    config = function()
      require("leap").add_default_mappings()

        -- https://github.com/ggandor/leap.nvim#faq
        -- Workaround for the duplicate cursor bug | https://github.com/ggandor/leap.nvim/issues/70#issuecomment-1521177534
        vim.api.nvim_create_autocmd(
          "User",
          {
            callback = function()
              vim.cmd.hi("Cursor", "blend=100")
              vim.opt.guicursor:append { "a:Cursor/lCursor" }
            end,
            pattern = "LeapEnter"
          }
        )
        vim.api.nvim_create_autocmd(
          "User",
          {
            callback = function()
              vim.cmd.hi("Cursor", "blend=0")
              vim.opt.guicursor:remove { "a:Cursor/lCursor" }
            end,
            pattern = "LeapLeave"
          }
        )

        -- Bidirectional search
        vim.keymap.set("n", "mm", function()
          local current_window = vim.fn.win_getid()
          require('leap').leap { target_windows = { current_window } }
        end)
    end,
  },
  {
    "kylechui/nvim-surround",
    event = "BufRead",
    config = function()
      require("nvim-surround").setup()
    end
  },
  {
    "folke/zen-mode.nvim",
    event = "BufRead",
  },
  {
    "kevinhwang91/rnvimr",
    event = "BufRead",
    cmd = "RnvimrToggle",
    config = function()
      vim.g.rnvimr_draw_border = 1
      vim.g.rnvimr_pick_enable = 1
      vim.g.rnvimr_bw_enable = 1
    end,
  },
  {
    "nacro90/numb.nvim",
    event = "BufRead",
    config = function()
      require("numb").setup {
        show_numbers = true,    -- Enable 'number' for the window while peeking
        show_cursorline = true, -- Enable 'cursorline' for the window while peeking
      }
    end,
  },
  {
    "uga-rosa/translate.nvim",
    event = "BufRead",
    config = function()
      require("translate").setup({
        default = {
          command = "translate_shell",
        },
        preset = {
          output = {
            split = {
              append = true,
            },
          },
        },
      })
    end,
  },
  {
    "iamcco/markdown-preview.nvim",
    event = "BufRead",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
  },
  {
    "github/copilot.vim",
    event = "VimEnter",
    cmd = { "Copilot" },
    config = function()
      -- Mapping tab is already used by NvChad
      -- https://github.com/LunarVim/LunarVim/issues/1856#issuecomment-954224770
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
      vim.g.copilot_tab_fallback = ""
      -- The mapping is set to other key, see ~/.config/nvim/lua/custom/mappings.lua
      -- or run <leader>ch to see copilot mapping section
    end,
  },
  -- TODO try copilot.lua or copilot-cmp, eg. https://gist.github.com/ianchesal/93ba7897f81618ca79af01bc413d0713
}

return plugins
