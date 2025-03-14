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
  "lualine.nvim", -- TODO: custom
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
      opts.colorscheme = LazyVim.has("tokyonight.nvim") and "tokyonight-night" or function() end
      require("lazyvim").setup(opts)
    end,
  },
  { "RRethy/vim-illuminate", optional = true, event = "VeryLazy" },
}
