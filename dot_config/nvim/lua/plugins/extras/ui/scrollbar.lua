return {
  {
    "petertriho/nvim-scrollbar",
    event = "VeryLazy",
    opts = function()
      local config = require("scrollbar.config").get()

      -- local enabled = true
      U.toggle.map("<leader>uS", {
        name = "Scroll Bar",
        get = function()
          return require("scrollbar.config").get().show
          -- return enabled
        end,
        set = function(state)
          -- enabled = state
          if state then
            vim.cmd("ScrollbarShow")
          else
            vim.cmd("ScrollbarHide")
          end
        end,
      })

      return {
        excluded_filetypes = vim.list_extend(vim.deepcopy(config.excluded_filetypes), {
          "dashboard",
          "neo-tree",
          "neo-tree-popup",
          "minifiles",
          "edgy",
          "trouble",
          "notify",
          "rip-substitute",
          "qf",
          "lazy",
          "mason",
          "Avante",
          "AvanteInput",
          "copilot-chat",
        }),
      }
    end,
  },

  {
    "folke/zen-mode.nvim",
    optional = true,
    opts = function(_, opts)
      local on_open = opts.on_open or function() end
      local on_close = opts.on_close or function() end

      opts.on_open = function()
        on_open()
        if package.loaded["scrollbar"] then
          vim.cmd("ScrollbarHide")
        end
      end
      opts.on_close = function()
        on_close()
        if package.loaded["scrollbar"] then
          vim.cmd("ScrollbarShow")
        end
      end
    end,
  },
}
