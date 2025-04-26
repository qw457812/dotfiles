---@diagnostic disable: missing-fields
return {
  { "folke/lazy.nvim", version = false },
  {
    "LazyVim/LazyVim",
    version = false,
    ---@type LazyVimOptions
    opts = {
      news = { lazyvim = true, neovim = true },
    },
  },
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>n",
        function()
          Snacks.notifier.hide()
          Snacks.notifier.show_history()
        end,
        desc = "Notification History",
      },
      {
        "<leader>N",
        function()
          Snacks.notifier.hide()
          Snacks.picker.notifications()
        end,
        desc = "Notification History",
      },
      {
        "<leader>ft",
        function()
          Snacks.scratch({ icon = " ", name = "Todo", ft = "markdown", file = "~/TODO.md" })
        end,
        desc = "Todo List",
      },
      {
        "<leader>gO",
        function()
          Snacks.gitbrowse({ what = "permalink" })
          U.stop_visual_mode()
        end,
        mode = { "n", "x" },
        desc = "Git Browse (open)",
      },
      {
        "<leader>gY",
        function()
          Snacks.gitbrowse({
            what = "permalink",
            open = function(url)
              vim.fn.setreg(vim.v.register, url)
              U.stop_visual_mode()
              LazyVim.info(url, { title = "Copied URL" })
            end,
            notify = false,
          })
        end,
        mode = { "n", "x" },
        desc = "Git Browse (copy)",
      },
    },
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      input = {
        win = {
          keys = {
            i_c_c = { "<C-c>", { "cmp_close", "cancel" }, mode = "i", expr = true },
            n_k = { "k", { "hist_up" }, mode = "n" },
            n_j = { "j", { "hist_down" }, mode = "n" },
          },
        },
      },
      notifier = {
        width = vim.g.user_is_termux and { min = 20, max = 0.7 } or nil,
        sort = { "added" }, -- sort only by time
        icons = { error = "󰅚", warn = "", info = "󰋽", debug = "󰃤", trace = "󰓗" },
        -- style = "fancy",
        -- top_down = false,
        -- filter = function(notif) return true end,
      },
      scroll = {
        animate = {
          duration = { step = 10, total = 100 },
        },
        animate_repeat = {
          duration = { step = 0, total = 0 }, -- holding down `<C-d>`
        },
      },
      terminal = {
        win = {
          position = "float", -- alternative: style = "float"
        },
      },
      image = {
        enabled = vim.g.user_is_wezterm or vim.g.user_is_kitty,
      },
      lazygit = {
        win = vim.g.user_is_termux and {
          height = vim.o.lines,
          width = vim.o.columns,
          border = "none",
        } or nil,
      },
      zen = {
        toggles = {
          dim = false,
          inlay_hints = false,
        },
        -- show = {
        --   tabline = true,
        -- },
        win = {
          -- -- copied from: https://github.com/AstroNvim/AstroNvim/blob/f8f67b007407c06065e535874dd8dc32d241b0c1/lua/astronvim/plugins/snacks.lua#L88-L92
          -- height = 0.9,
          backdrop = {
            transparent = false,
            -- win = { wo = { winhighlight = "Normal:Normal" } },
          },
          wo = {
            winbar = "",
            -- number = false,
            -- list = false,
          },
        },
        zoom = {
          win = {
            -- height = 0, -- full width, overrides `opts.zen.win.height`, in favor of zoom_indicator
            w = {
              snacks_zen_zoom = true,
            },
          },
        },
      },
      styles = {
        zoom_indicator = {
          bo = { filetype = "snacks_zen_zoom_indicator" },
        },
        notification_history = {
          zindex = 99, -- lower than notification
          width = 0.95,
          height = 0.95,
          wo = { wrap = true, conceallevel = 0 },
        },
      },
    },
  },
  {
    "folke/snacks.nvim",
    ---@param opts snacks.Config
    opts = function(_, opts)
      opts.zen = opts.zen or {}
      local on_open = opts.zen.on_open or function() end
      opts.zen.on_open = function(win)
        on_open(win)
        -- vim.wo[win.win].winbar = ""
        -- vim.api.nvim_create_autocmd("BufWinEnter", {
        --   group = win.augroup,
        --   callback = function()
        --     if not vim.api.nvim_win_is_valid(win.win) then
        --       return true
        --     end
        --     vim.wo[win.win].winbar = ""
        --   end,
        -- })
        vim.b[win.buf].snacks_indent_old = vim.b[win.buf].snacks_indent
        if not vim.w[win.win].snacks_zen_zoom then
          vim.b[win.buf].snacks_indent = false
        end
      end
      local on_close = opts.zen.on_close or function() end
      opts.zen.on_close = function(win)
        on_close(win)
        vim.b[win.buf].snacks_indent = vim.b[win.buf].snacks_indent_old
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "bigfile",
        callback = function(ev)
          vim.b[ev.buf].bigfile = true
        end,
      })
    end,
  },
}
