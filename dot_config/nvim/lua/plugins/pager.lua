if not (vim.g.pager or vim.g.manpager or vim.g.terminal_scrollback_pager) then
  return {}
end

local enabled = {
  "LazyVim",
  "lazy.nvim",
  "snacks.nvim",
  "mini.ai",
  -- the plugins below are optional
  "yanky.nvim",
  "which-key.nvim",
  "tokyonight.nvim",
  "lualine.nvim",
  "mini.icons", -- for lualine.nvim
  "noice.nvim",
  "nui.nvim", -- for noice.nvim
  "vim-illuminate",
}

local Config = require("lazy.core.config")
Config.options.checker.enabled = false
Config.options.change_detection.enabled = false
Config.options.defaults.cond = function(plugin)
  ---@diagnostic disable-next-line: undefined-field
  return vim.tbl_contains(enabled, plugin.name) or plugin.pager
end
vim.g.snacks_animate = false

return {
  {
    "snacks.nvim",
    ---@module "snacks"
    ---@param opts snacks.Config
    config = function(_, opts)
      ---@type snacks.Config
      local o = {
        bigfile = { enabled = false },
        dashboard = { enabled = false },
        indent = { enabled = false },
        input = { enabled = false },
        quickfile = { enabled = false },
        scroll = { enabled = false },
        image = { enabled = false },
        scope = { enabled = false },
        words = { enabled = false },
        -- notifier = { enabled = false }, -- enabled for noice.nvim
        -- picker = { enabled = false }, -- enabled `vim.ui.select` for `gx` via nvim-various-textobjs
      }
      -- copied from: https://github.com/LazyVim/LazyVim/blob/ba632c500da56532c122539c45fe3511fd894a05/lua/lazyvim/plugins/init.lua#L22-L28
      local notify = vim.notify
      require("snacks").setup(vim.tbl_deep_extend("force", opts, o))
      if LazyVim.has("noice.nvim") then
        vim.notify = notify
      end
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = function()
      local has_kitty_scrollback_nvim = LazyVim.has("kitty-scrollback.nvim")

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymaps",
        once = true,
        callback = function()
          vim.keymap.set("n", "<Esc>", function()
            if
              not U.keymap.clear_ui_esc({
                popups = vim.bo.filetype ~= "kitty-scrollback", -- status_window of kitty-scrollback.nvim
              })
            then
              if vim.g.user_close_key then
                vim.api.nvim_feedkeys(vim.keycode(vim.g.user_close_key), "m", false)
              else
                vim.cmd([[quit]])
              end
            end
          end, { desc = "Clear UI or Quit" })
          if vim.g.terminal_scrollback_pager and not has_kitty_scrollback_nvim then
            vim.keymap.set("n", "i", "<cmd>qa<cr>", { desc = "Quit All" })
            vim.keymap.set("n", "<C-c>", "<cmd>qa<cr>", { desc = "Quit All" })
          end
        end,
      })

      if vim.g.terminal_scrollback_pager then
        if not has_kitty_scrollback_nvim then
          LazyVim.on_very_lazy(function()
            vim.defer_fn(function()
              vim.cmd("normal! G")
            end, 100)
          end)
        end
      elseif vim.g.manpager and vim.g.user_is_termux then
        -- fix the `command man chezmoi | eval $MANPAGER` open a empty buffer
        LazyVim.on_very_lazy(function()
          if vim.api.nvim_buf_get_name(0) == "man://" then
            vim.cmd([[quit]])
          end
        end)
      end
    end,
    config = function(_, opts)
      opts.colorscheme = LazyVim.has("tokyonight.nvim") and "tokyonight-moon" or function() end
      require("lazyvim").setup(opts)
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    config = function(_, opts)
      opts.sections.lualine_a = {
        {
          function()
            return vim.g.terminal_scrollback_pager and (vim.g.user_is_kitty and "KITTY" or "TERM")
              or vim.g.manpager and "MAN"
              or "PAGER"
          end,
        },
      }
      opts.sections.lualine_b = {
        {
          function()
            return vim.g.terminal_scrollback_pager and "scrollback"
              or vim.g.manpager and vim.api.nvim_buf_get_name(0):match("man://(.*)")
              or ""
          end,
        },
      }
      opts.sections.lualine_c = {
        {
          function()
            return vim.g.terminal_scrollback_pager and (vim.g.user_is_kitty and "󰄛 " or "")
              or vim.g.manpager and "󰗚 "
              or ""
          end,
          color = function()
            return { fg = Snacks.util.color("MiniIconsYellow") }
          end,
        },
      }
      opts.sections.lualine_x = { U.lualine.hlsearch, U.lualine.command }
      opts.sections.lualine_y = { { "progress" } }
      opts.extensions = {}
      if
        vim.g.terminal_scrollback_pager
        and LazyVim.has("tokyonight.nvim")
        and vim.startswith(vim.g.colors_name or "", "tokyonight")
      then
        local tokyonight = require("lualine.themes.tokyonight")
        tokyonight.normal.a.bg, tokyonight.normal.b.fg = tokyonight.replace.a.bg, tokyonight.replace.b.fg
        opts.options.theme = tokyonight
      end
      require("lualine").setup(opts)
    end,
  },
  { "RRethy/vim-illuminate", optional = true, event = "VeryLazy" },
}
