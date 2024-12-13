return {
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
        -- https://github.com/bleek42/dev-env-config-backup/blob/099eb0c4468a03bcafb6c010271818fe8a794816/src/Linux/config/nvim/lua/user/plugins/editor.lua#L27
        on_open = function(win)
          on_open()
          -- vim.g.user_zenmode_on = true -- require("zen-mode.view").is_open()
          vim.g.user_minianimate_disable_old = vim.g.minianimate_disable
          vim.g.minianimate_disable = true
          vim.g.user_winbar_old = vim.wo.winbar
          vim.wo.winbar = nil
          -- -- show bufferline in zen mode
          -- if package.loaded["bufferline"] and require("bufferline.utils").get_buf_count() > 1 then
          --   vim.g.user_neotree_visible_old = vim.g.user_neotree_visible
          --   if vim.g.user_neotree_visible then
          --     require("neo-tree.command").execute({ action = "close" })
          --   end
          --   local view = require("zen-mode.view")
          --   local layout = view.layout(view.opts)
          --   vim.api.nvim_win_set_config(win, {
          --     width = layout.width,
          --     height = layout.height - 1,
          --   })
          --   vim.api.nvim_win_set_config(view.bg_win, {
          --     width = vim.o.columns,
          --     height = view.height() - 1,
          --     row = 1,
          --     col = layout.col,
          --     relative = "editor",
          --   })
          -- end
        end,
        on_close = function()
          on_close()
          -- vim.g.user_zenmode_on = false
          vim.g.minianimate_disable = vim.g.user_minianimate_disable_old
          vim.wo.winbar = vim.g.user_winbar_old
          -- if vim.g.user_neotree_visible_old then
          --   require("neo-tree.command").execute({ action = "show" })
          -- end
        end,
      })
    end,
  },
}
