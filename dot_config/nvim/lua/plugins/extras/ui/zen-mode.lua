return {
  {
    "folke/twilight.nvim",
    cmd = "Twilight",
    opts = {
      context = 20,
    },
  },
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      {
        "<leader>Z",
        function()
          require("zen-mode").toggle({ plugins = { twilight = { enabled = true } } })
        end,
        desc = "Zen Mode (Twilight)",
      },
    },
    opts = function(_, opts)
      local on_open = opts.on_open or function() end
      local on_close = opts.on_close or function() end

      return vim.tbl_deep_extend("force", opts, {
        window = { backdrop = 0.7 },
        plugins = {
          gitsigns = true,
          tmux = true,
          neovide = { enabled = true, scale = 1 },
          kitty = { enabled = false, font = "+2" },
          alacritty = { enabled = false, font = "14" },
          twilight = { enabled = false }, -- bad performance
        },
        on_open = function(win)
          on_open()
          -- vim.g.user_zenmode_on = true -- require("zen-mode.view").is_open()
          vim.g.user_minianimate_disable_old = vim.g.minianimate_disable
          vim.g.minianimate_disable = true
          vim.g.user_winbar_old = vim.wo.winbar
          vim.wo.winbar = ""
        end,
        on_close = function()
          on_close()
          -- vim.g.user_zenmode_on = false
          vim.g.minianimate_disable = vim.g.user_minianimate_disable_old
          vim.wo.winbar = vim.g.user_winbar_old
        end,
      })
    end,
  },
}
