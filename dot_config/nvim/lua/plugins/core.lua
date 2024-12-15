return {
  { "folke/lazy.nvim", version = false },
  { "LazyVim/LazyVim", version = false },
  {
    "LazyVim/LazyVim",
    opts = function()
      -- HACK: undo https://github.com/LazyVim/LazyVim/commit/15c81fd in favor of U.keymap.clear_ui_esc
      local orig_on_key
      LazyVim.on_load("snacks.nvim", function()
        orig_on_key = Snacks.util.on_key
        function Snacks.util.on_key(key, cb)
          if key:lower() == "<esc>" then
            return
          end
          orig_on_key(key, cb)
        end
      end)
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymapsDefaults",
        callback = function()
          Snacks.util.on_key = orig_on_key
        end,
      })
    end,
  },
  {
    "folke/snacks.nvim",
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      input = {
        win = {
          keys = {
            i_c_c = { "<C-c>", { "cmp_close", "cancel" }, mode = "i" },
            i_esc = { "<esc>", "stopinsert", mode = "i" },
            esc = { "<esc>", "cancel" },
            cr = { "<cr>", "confirm" },
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
    opts = function(_, opts)
      opts.zen = opts.zen or {}
      local on_open = opts.zen.on_open or function() end
      ---@param win snacks.win
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
