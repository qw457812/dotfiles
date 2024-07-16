return {
  -- :h bufferline-configuration
  {
    "akinsho/bufferline.nvim",
    keys = {
      { "<Up>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<Down>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "<leader>bH", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto First Buffer" },
      { "<leader>b1", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Goto Buffer 1" },
      { "<leader>b2", "<cmd>BufferLineGoToBuffer 2<cr>", desc = "Goto Buffer 2" },
      { "<leader>b3", "<cmd>BufferLineGoToBuffer 3<cr>", desc = "Goto Buffer 3" },
      { "<leader>b4", "<cmd>BufferLineGoToBuffer 4<cr>", desc = "Goto Buffer 4" },
      { "<leader>b5", "<cmd>BufferLineGoToBuffer 5<cr>", desc = "Goto Buffer 5" },
      { "<leader>b6", "<cmd>BufferLineGoToBuffer 6<cr>", desc = "Goto Buffer 6" },
      { "<leader>b7", "<cmd>BufferLineGoToBuffer 7<cr>", desc = "Goto Buffer 7" },
      { "<leader>b8", "<cmd>BufferLineGoToBuffer 8<cr>", desc = "Goto Buffer 8" },
      { "<leader>b9", "<cmd>BufferLineGoToBuffer 9<cr>", desc = "Goto Buffer 9" },
      { "<leader>bL", "<cmd>BufferLineGoToBuffer -1<cr>", desc = "Goto Last Buffer" },
    },
    opts = {
      options = {
        separator_style = "slope",
      },
    },
  },

  -- https://github.com/folke/dot/blob/master/nvim/lua/plugins/ui.lua
  {
    "folke/twilight.nvim",
    cmd = "Twilight",
    opts = {
      context = 20, -- default value: 10
    },
  },
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    -- opts = function()
    --   local zen_mode_group = vim.api.nvim_create_augroup("restore_zen_mode_vim_leave_pre", { clear = true })
    --   return {
    --     plugins = {
    --       gitsigns = true,
    --       tmux = true,
    --       neovide = { enabled = true, scale = 1 },
    --       kitty = { enabled = false, font = "+2" },
    --       alacritty = { enabled = false, font = "14" },
    --       twilight = { enabled = false },
    --     },
    --     -- https://github.com/TranThangBin/init.lua/blob/3a357269ecbcb88d2a8b727cb1820541194f3283/lua/tranquangthang/lazy/zen-mode.lua#L39
    --     on_open = function()
    --       -- https://github.com/folke/zen-mode.nvim/issues/111
    --       vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    --         group = zen_mode_group,
    --         desc = "Restore tmux status line when close Neovim in Zen Mode",
    --         callback = function()
    --           require("zen-mode").close()
    --         end,
    --       })
    --     end,
    --     on_close = function()
    --       vim.api.nvim_clear_autocmds({ group = zen_mode_group })
    --     end,
    --   }
    -- end,
    keys = {
      { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen Mode" },
      {
        "<leader>Z",
        function()
          require("zen-mode").toggle({ plugins = { twilight = { enabled = true } } })
        end,
        desc = "Zen Mode (Twilight)",
      },
    },
    opts = {
      plugins = {
        gitsigns = true,
        tmux = true,
        neovide = { enabled = true, scale = 1 },
        kitty = { enabled = false, font = "+2" },
        alacritty = { enabled = false, font = "14" },
        twilight = { enabled = false },
      },
      on_open = function()
        vim.env.ZEN_MODE_ON = true
      end,
      on_close = function()
        vim.env.ZEN_MODE_ON = nil
      end,
    },
    config = function(_, opts)
      require("zen-mode").setup(opts)
      -- https://github.com/folke/zen-mode.nvim/issues/111
      vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
        desc = "Restore tmux status line when close Neovim in Zen Mode",
        callback = function()
          if vim.env.ZEN_MODE_ON then
            require("zen-mode").close()
          end
        end,
      })
    end,
  },

  {
    "shortcuts/no-neck-pain.nvim",
    opts = {
      width = 120, -- same width as zen-mode.nvim, default value: 100
    },
    keys = {
      { "<leader>uz", "<cmd>NoNeckPain<cr>", desc = "No Neck Pain" },
      { "<leader>uZ", ":NoNeckPainResize ", desc = "Resize the No-Neck-Pain window" },
    },
  },

  {
    "tzachar/highlight-undo.nvim",
    event = "VeryLazy",
    vscode = true,
    opts = function()
      -- link: Search IncSearch Substitute
      vim.api.nvim_set_hl(0, "HighlightUndo", { default = true, link = "Substitute" })
      vim.api.nvim_set_hl(0, "HighlightRedo", { default = true, link = "HighlightUndo" })
      return {
        --[[add custom config here]]
      }
    end,
  },
}
