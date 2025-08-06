---@module "lazy"
---@type LazySpec
return {
  { "folke/lazy.nvim", version = false },
  {
    "LazyVim/LazyVim",
    version = false,
    ---@module "lazyvim"
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
      indent = {
        -- enable `only_current` to fix issues like: https://github.com/lukas-reineke/indent-blankline.nvim/issues/622#issuecomment-1707489777
        indent = {
          only_current = true,
        },
        scope = {
          only_current = true,
        },
        chunk = {
          enabled = true,
          only_current = true,
        },
        -- -- alternative to `only_current`, note that indent in floating windows like zen/zoom will be disabled in this case
        -- filter = function(buf)
        --   -- copied from: https://github.com/folke/snacks.nvim/blob/cddf714dd66a14b0cf556f9be82165b22517de1a/lua/snacks/indent.lua#L78-L80
        --   return vim.g.snacks_indent ~= false
        --     and vim.b[buf].snacks_indent ~= false
        --     and vim.bo[buf].buftype == ""
        --     and #vim.fn.win_findbuf(buf) == 1
        -- end,
      },
      scroll = {
        animate = {
          duration = { step = 10, total = 100 },
        },
        animate_repeat = {
          duration = { step = 0, total = 0 }, -- holding down `<C-d>`
        },
      },
      image = {
        enabled = vim.g.user_is_wezterm or vim.g.user_is_kitty,
      },
      -- alternative: https://github.com/stevearc/profile.nvim
      profiler = {
        presets = {
          on_stop = function()
            Snacks.profiler.scratch()
          end,
        },
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
