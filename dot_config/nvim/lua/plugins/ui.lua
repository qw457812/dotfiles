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
    opts = function()
      local zen_mode_group = vim.api.nvim_create_augroup("zen_mode_tmux_status", { clear = true })
      return {
        plugins = {
          gitsigns = true,
          tmux = true,
          neovide = { enabled = true, scale = 1 },
          kitty = { enabled = false, font = "+2" },
          alacritty = { enabled = false, font = "14" },
          twilight = { enabled = false },
        },
        -- https://github.com/TranThangBin/init.lua/blob/3a357269ecbcb88d2a8b727cb1820541194f3283/lua/tranquangthang/lazy/zen-mode.lua#L39
        -- https://github.com/folke/zen-mode.nvim/blob/a31cf7113db34646ca320f8c2df22cf1fbfc6f2a/lua/zen-mode/plugins.lua#L96
        on_open = function()
          vim.env.NVIM_USER_ZEN_MODE_ON = 1
          vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend" }, {
            group = zen_mode_group,
            desc = "show tmux status line on neovim focus lost",
            callback = function()
              if vim.env.TMUX then
                vim.fn.system([[tmux set status on]])
              end
            end,
          })
          vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
            group = zen_mode_group,
            desc = "hide tmux status line on neovim focus gained",
            callback = function()
              if vim.env.TMUX then
                vim.fn.system([[tmux set status off]])
              end
            end,
          })
        end,
        on_close = function()
          vim.env.NVIM_USER_ZEN_MODE_ON = nil
          vim.api.nvim_clear_autocmds({ group = zen_mode_group })
        end,
      }
    end,
    config = function(_, opts)
      require("zen-mode").setup(opts)
      -- https://github.com/folke/zen-mode.nvim/issues/111
      vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
        desc = "Restore tmux status line when close Neovim in Zen Mode",
        callback = function()
          if vim.env.NVIM_USER_ZEN_MODE_ON then
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
