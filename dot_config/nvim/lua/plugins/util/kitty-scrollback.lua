if not (vim.g.kitty_scrollback or vim.g.manpager) then
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
  return vim.tbl_contains(enabled, plugin.name) or plugin.kitty_scrollback
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
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimKeymaps",
        once = true,
        callback = function()
          vim.keymap.set("n", "i", "<cmd>qa<cr>", { desc = "Quit" })
          vim.keymap.set("n", "<Esc>", function()
            if not U.keymap.clear_ui_esc({ close = false }) then
              vim.cmd("qa")
            end
          end, { desc = "Clear UI or Quit" })
        end,
      })
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
      -- stylua: ignore start
      opts.sections.lualine_a = { { function() return vim.g.manpager and "man" or "kitty" end } }
      opts.sections.lualine_b = {
        {
          function() return vim.g.manpager and vim.api.nvim_buf_get_name(0):match("man://(.*)") or "scrollback" end,
        },
      }
      opts.sections.lualine_c = {
        {
          function() return vim.g.manpager and "󰗚 " or "󰄛 " end,
          color = function() return { fg = Snacks.util.color("MiniIconsYellow") } end,
        },
      }
      -- stylua: ignore end
      opts.sections.lualine_x = { U.lualine.hlsearch, U.lualine.command }
      opts.sections.lualine_y = { { "progress" } }
      opts.extensions = {}
      require("lualine").setup(opts)
    end,
  },
  { "RRethy/vim-illuminate", optional = true, event = "VeryLazy" },
}
