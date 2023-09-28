local M = {}

M.config = function()
  lvim.plugins = {
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
      event = "VeryLazy",
      config = function()
        require("nvim-surround").setup()
      end
    },
    {
      "max397574/better-escape.nvim",
      event = "InsertEnter",
      config = function()
        require("better_escape").setup {
          mapping = { "jk", "jj", "kj" }, -- a table with mappings to use
          timeout = vim.o.timeoutlen,     -- the time in which the keys must be hit in ms. Use option timeoutlen by default
          clear_empty_lines = false,      -- clear line after escaping if there is only whitespace
          keys = "<Esc>",                 -- keys used for escaping, if it is a function will use the result everytime
        }
      end,
    },
    {
      "folke/zen-mode.nvim",
      event = "BufRead",
    },
    {
      "kevinhwang91/rnvimr",
      event = "VeryLazy",
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
      event = "VeryLazy",
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
      "kevinhwang91/nvim-bqf",
      event = { "BufRead", "BufNew" },
      config = function()
        require("bqf").setup({
          auto_enable = true,
          preview = {
            win_height = 12,
            win_vheight = 12,
            delay_syntax = 80,
            border_chars = { "┃", "┃", "━", "━", "┏", "┓", "┗", "┛", "█" },
          },
          func_map = {
            vsplit = "",
            ptogglemode = "z,",
            stoggleup = "",
          },
          filter = {
            fzf = {
              action_for = { ["ctrl-s"] = "split" },
              extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
            },
          },
        })
      end,
    },
    {
      "windwp/nvim-spectre",
      event = "BufRead",
      config = function()
        require("spectre").setup()

        -- https://github.com/nvim-pack/nvim-spectre#usage
        vim.keymap.set('n', '<leader>S', '<cmd>lua require("spectre").open()<CR>', {
          desc = "Open Spectre"
        })
        vim.keymap.set('n', '<leader>sw', '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', {
          desc = "Search current word"
        })
        vim.keymap.set('v', '<leader>sw', '<esc><cmd>lua require("spectre").open_visual()<CR>', {
          desc = "Search current word"
        })
        -- vim.keymap.set('n', '<leader>sp', '<cmd>lua require("spectre").open_file_search({select_word=true})<CR>', {
        --   desc = "Search on current file"
        -- })
      end,
    },
    {
      -- https://github.com/LunarVim/starter.lvim/blob/java-ide/config.lua
      "mfussenegger/nvim-jdtls",
      event = "VeryLazy",
    },
    {
      "romgrk/nvim-treesitter-context",
      event = "BufRead",
      config = function()
        require("treesitter-context").setup {
          enable = true,   -- Enable this plugin (Can be enabled/disabled later via commands)
          throttle = true, -- Throttles plugin updates (may improve performance)
          max_lines = 0,   -- How many lines the window should span. Values <= 0 mean no limit.
          patterns = {     -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
            -- For all filetypes
            -- Note that setting an entry here replaces all other patterns for this entry.
            -- By setting the 'default' entry below, you can control which nodes you want to
            -- appear in the context window.
            default = {
              'class',
              'function',
              'method',
            },
          },
        }
      end,
    },
    {
      "karb94/neoscroll.nvim",
      event = "WinScrolled",
      config = function()
        require('neoscroll').setup({
          -- All these keys will be mapped to their corresponding default scrolling animation
          -- mappings = { '<C-u>', '<C-d>', '<C-b>', '<C-f>',
          --   '<C-y>', '<C-e>', 'zt', 'zz', 'zb' },
          mappings = { '<C-b>', '<C-f>', '<C-y>', '<C-e>', 'zt', 'zz', 'zb' },
          hide_cursor = true,          -- Hide cursor while scrolling
          stop_eof = true,             -- Stop at <EOF> when scrolling downwards
          use_local_scrolloff = false, -- Use the local scope of scrolloff instead of the global scope
          respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
          cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
          easing_function = nil,       -- Default easing function
          pre_hook = nil,              -- Function to run before the scrolling animation starts
          post_hook = nil,             -- Function to run after the scrolling animation ends
        })
      end
    },
    {
      "ellisonleao/glow.nvim",
      event = "BufRead",
      config = true,
      cmd = "Glow"
    },
    {
      "iamcco/markdown-preview.nvim",
      event = "BufRead",
      ft = "markdown",
      build = function()
        vim.fn["mkdp#util#install"]()
      end,
    },
    {
      "github/copilot.vim",
      event = "VimEnter",
      cmd = { "Copilot" },
      config = function()
        -- :help copilot
        -- https://github.com/LunarVim/LunarVim/issues/1856#issuecomment-954224770
        vim.g.copilot_no_tab_map = true
        vim.g.copilot_assume_mapped = true
        vim.g.copilot_tab_fallback = ""
        local cmp = require "cmp"
        lvim.builtin.cmp.mapping["<Tab>"] = function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          else
            local copilot_keys = vim.fn["copilot#Accept"]()
            if copilot_keys ~= "" then
              vim.api.nvim_feedkeys(copilot_keys, "i", true)
            else
              fallback()
            end
          end
        end
        -- https://github.com/orgs/community/discussions/8105#discussioncomment-3486946
        vim.api.nvim_set_keymap("i", "<C-l>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
        vim.api.nvim_set_keymap("i", "<C-j>", 'copilot#Next()', { silent = true, expr = true })
        vim.api.nvim_set_keymap("i", "<C-k>", 'copilot#Previous()', { silent = true, expr = true })
      end,
    },
    -- {
    --   "zbirenbaum/copilot.lua",
    --   cmd = "Copilot",
    --   event = "InsertEnter",
    --   config = function()
    --     require("copilot").setup({})
    --   end,
    -- },

    -- Theme    https://github.com/rockerBOO/awesome-neovim#colorscheme
    -- =========================================
    {
      'projekt0n/github-nvim-theme',
      lazy = not vim.startswith(lvim.colorscheme, "github"),
      -- priority = 1000, -- make sure to load this before all the other start plugins
      config = function()
        require('github-theme').setup()
      end,
    },
    {
      "catppuccin/nvim",
      name = "catppuccin",
      lazy = not vim.startswith(lvim.colorscheme, "catppuccin"),
    },
    {
      "rebelot/kanagawa.nvim",
      lazy = not vim.startswith(lvim.colorscheme, "kanagawa"),
    },
    {
      'rose-pine/neovim',
      name = 'rose-pine',
      lazy = not vim.startswith(lvim.colorscheme, "rose-pine"),
    },
    {
      -- Theme inspired by Atom
      'navarasu/onedark.nvim',
      lazy = not vim.startswith(lvim.colorscheme, "onedark"),
    },
  }
end

return M
