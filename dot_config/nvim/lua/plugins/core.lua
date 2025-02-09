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
    },
    ---@module "snacks"
    ---@type snacks.Config
    opts = {
      input = {
        win = {
          keys = {
            i_c_c = { "<C-c>", { "cmp_close", "cancel" }, mode = "i", expr = true },
            n_cr = { "<cr>", "confirm", mode = "n", expr = true },
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
      -- zen = {
      --   show = {
      --     tabline = true,
      --   },
      -- },
      gitbrowse = {
        url_patterns = {
          ["github%.com"] = {
            file = function(fields)
              ---@param cmd string[]
              ---@param err string
              local function system(cmd, err)
                local proc = vim.fn.system(cmd)
                if vim.v.shell_error ~= 0 then
                  Snacks.notify.error({ err, proc }, { title = "Git Browse" })
                  error("__ignore__")
                end
                return vim.split(vim.trim(proc), "\n")
              end

              local file = vim.api.nvim_buf_get_name(0) ---@type string?
              file = file and (vim.uv.fs_stat(file) or {}).type == "file" and vim.fs.normalize(file) or nil
              local cwd = file and vim.fn.fnamemodify(file, ":h") or vim.fn.getcwd()
              -- copied from: https://github.com/folke/snacks.nvim/pull/438
              fields.commit = fields.commit
                or system(
                  { "git", "-C", cwd, "log", "-n", "1", "--pretty=format:%H", "--", file },
                  "Failed to get latest commit of file"
                )[1]

              local pattern = "/blob/{commit}/{file}#L{line_start}-L{line_end}"
              -- copied from: https://github.com/folke/snacks.nvim/blob/140204fde53531dd5dc5bd222975a9ff350747ad/lua/snacks/gitbrowse.lua#L97-L99
              return (
                pattern:gsub("(%b{})", function(key)
                  return fields[key:sub(2, -2)] or key
                end)
              )
            end,
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

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "bigfile",
        callback = function(ev)
          vim.b[ev.buf].bigfile = true
        end,
      })
    end,
  },
}
