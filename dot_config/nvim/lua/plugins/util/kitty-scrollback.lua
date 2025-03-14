if not vim.g.kitty_scrollback then
  return {}
end

local enabled = {
  "LazyVim",
  "lazy.nvim",
  "mini.ai",
  "snacks.nvim",
  "yanky.nvim",
  -- the plugins below are optional
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
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = false },
      dashboard = { enabled = false },
      indent = { enabled = false },
      input = { enabled = false },
      -- notifier = { enabled = false }, -- enabled for lualine.nvim
      -- picker = { enabled = false }, -- enabled for `gx` via nvim-various-textobjs
      quickfile = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = false },
      image = { enabled = false },
      scope = { enabled = false },
      words = { enabled = false },
    },
  },
  {
    "LazyVim/LazyVim",
    config = function(_, opts)
      opts = opts or {}
      opts.colorscheme = LazyVim.has("tokyonight.nvim") and "tokyonight-moon" or function() end
      require("lazyvim").setup(opts)
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    config = function(_, opts)
      -- stylua: ignore start
      opts.sections.lualine_a = { { function() return "kitty" end } }
      opts.sections.lualine_b = { { function() return "scrollback" end } }
      opts.sections.lualine_c = {
        {
          function() return "󰄛 " end,
          color = function() return { fg = Snacks.util.color("MiniIconsYellow") } end,
        },
      }
      opts.sections.lualine_x = {
        {
          function() return require("noice").api.status.command.get() end,
          cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
          color = function() return { fg = Snacks.util.color("Statement") } end,
        },
      }
      -- stylua: ignore end
      opts.sections.lualine_y = { { "progress" } }
      opts.extensions = {}
      require("lualine").setup(opts)
    end,
  },
  { "RRethy/vim-illuminate", optional = true, event = "VeryLazy" },
}
