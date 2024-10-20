local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- bootstrap lazy.nvim
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    {
      "LazyVim/LazyVim",
      import = "lazyvim.plugins",
      opts = {
        news = {
          lazyvim = true,
          neovim = true,
        },
      },
    },
    -- import/override with your plugins
    { import = "plugins" },
    { import = "plugins.explorer" },
    { import = "plugins.lang" },
    { import = "plugins.util" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  concurrency = (jit.os:find("Windows") or vim.env.TERMUX_VERSION) and (vim.uv.available_parallelism() * 2) or nil,
  install = { colorscheme = { "tokyonight", "habamax" } },
  ui = {
    wrap = false, -- wrap the lines in the ui
    border = "rounded",
    icons = {
      keys = "󰥻 ",
    },
  },
  diff = { cmd = "terminal_git" },
  checker = {
    -- automatically check for plugin updates
    enabled = true,
    concurrency = vim.env.TERMUX_VERSION and 1 or nil,
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
