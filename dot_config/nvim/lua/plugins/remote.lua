if not (vim.env.NVIM_APPNAME == "nvim-remote" or vim.v.startreason == "remote-ssh") then
  return {}
end

local enabled = {
  "LazyVim",
  "lazy.nvim",
  "snacks.nvim",
  "tokyonight.nvim",
}

local Config = require("lazy.core.config")
Config.options.checker.enabled = false
Config.options.change_detection.enabled = false
Config.options.defaults.cond = function(plugin)
  ---@diagnostic disable-next-line: undefined-field
  return vim.tbl_contains(enabled, plugin.name) or plugin.remote
end
vim.g.snacks_animate = false

---@type LazySpec
return {
  {
    "snacks.nvim",
    opts = {
      dashboard = { enabled = false },
      image = { enabled = false },
      scroll = { enabled = false },
    },
  },
  {
    "LazyVim/LazyVim",
    config = function(_, opts)
      opts.colorscheme = LazyVim.has("tokyonight.nvim") and "tokyonight-moon" or function() end
      require("lazyvim").setup(opts)
    end,
  },
}
