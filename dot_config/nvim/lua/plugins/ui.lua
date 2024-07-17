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
      local opts = {
        plugins = {
          gitsigns = true,
          tmux = true,
          neovide = { enabled = true, scale = 1 },
          kitty = { enabled = false, font = "+2" },
          alacritty = { enabled = false, font = "14" },
          twilight = { enabled = false },
        },
      }
      if not vim.env.TMUX then
        return opts
      end

      -- https://github.com/folke/zen-mode.nvim/blob/a31cf7113db34646ca320f8c2df22cf1fbfc6f2a/lua/zen-mode/plugins.lua#L96
      local function get_tmux_opt(option)
        local option_raw = vim.fn.system([[tmux show -w ]] .. option)
        if option_raw == "" then
          option_raw = vim.fn.system([[tmux show -g ]] .. option)
        end
        local opt = vim.split(vim.trim(option_raw), " ")[2]
        return opt
      end
      local tmux_status = get_tmux_opt("status")
      local group = vim.api.nvim_create_augroup("zen_mode_tmux", { clear = true })
      -- https://github.com/TranThangBin/init.lua/blob/3a357269ecbcb88d2a8b727cb1820541194f3283/lua/tranquangthang/lazy/zen-mode.lua#L39
      opts.on_open = function()
        vim.env.NVIM_USER_ZEN_MODE_ON = 1
        -- restore tmux status line when switching to another tmux window or ctrl-z
        vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend" }, {
          group = group,
          desc = "Restore tmux status line on Neovim Focus Lost",
          callback = function()
            vim.fn.system(string.format([[tmux set status %s]], tmux_status))
          end,
        })
        vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
          group = group,
          desc = "Hide tmux status line on Neovim Focus Gained",
          callback = function()
            vim.fn.system([[tmux set status off]])
          end,
        })
      end
      opts.on_close = function()
        vim.env.NVIM_USER_ZEN_MODE_ON = nil
        vim.api.nvim_clear_autocmds({ group = group })
      end
      return opts
    end,
    config = function(_, opts)
      require("zen-mode").setup(opts)
      if vim.env.TMUX then
        -- https://github.com/folke/zen-mode.nvim/issues/111
        vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
          desc = "Restore tmux status line when close Neovim in Zen Mode",
          callback = function()
            if vim.env.NVIM_USER_ZEN_MODE_ON then
              require("zen-mode").close()
            end
          end,
        })
      end
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
