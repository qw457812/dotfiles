return {
  { "folke/lazy.nvim", version = false },
  { "LazyVim/LazyVim", version = false },
  {
    "folke/snacks.nvim",
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      input = {
        win = {
          keys = {
            i_c_c = { "<C-c>", { "cmp_close", "cancel" }, mode = "i" },
            n_cr = { "<cr>", "confirm", mode = "n" },
          },
        },
      },
      notifier = {
        width = vim.g.user_is_termux and { min = 20, max = 0.7 } or nil,
        sort = { "added" }, -- sort only by time
        icons = { error = "󰅚", warn = "", info = "󰋽", debug = "󰃤", trace = "󰓗" },
        -- style = "fancy",
        -- top_down = false,
      },
      scroll = {
        animate = {
          duration = { step = 10, total = 100 },
        },
      },
      terminal = {
        win = {
          position = "float", -- alternative: style = "float"
        },
      },
      -- zen = {
      --   show = {
      --     tabline = true,
      --   },
      -- },
    },
    init = function()
      LazyVim.on_very_lazy(function()
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- override print to use snacks for `:=` command
      end)
    end,
  },
  {
    "folke/snacks.nvim",
    ---@param opts snacks.Config
    opts = function(_, opts)
      opts.zen = opts.zen or {}
      local on_open = opts.zen.on_open or function() end
      opts.zen.on_open = function(win)
        on_open(win)
        vim.wo[win.win].winbar = nil
        vim.api.nvim_create_autocmd("BufWinEnter", {
          group = win.augroup,
          callback = function()
            if not vim.api.nvim_win_is_valid(win.win) then
              return true
            end
            vim.wo[win.win].winbar = nil
          end,
        })
      end

      Snacks.config.style("zoom_indicator", {
        bo = {
          filetype = "snacks_zen_zoom_indicator",
        },
      })
    end,
  },
}
