local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
    -- import plugins.lang, plugins.util, etc.
    unpack((function()
      local specs = {}
      for name, type in vim.fs.dir(vim.fn.stdpath("config") .. "/lua/plugins") do
        if type == "directory" and name ~= "specs" and name ~= "extras" then
          table.insert(specs, { import = "plugins." .. name })
        end
      end
      return specs
    end)()),
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
  git = {
    log = { "--since=7 days ago" }, -- show commits from the last x days
    -- building some plugins on termux can take a long time
    timeout = vim.env.TERMUX_VERSION and 600 or nil, -- kill processes that take more than x seconds
  },
  rocks = { hererocks = true },
  install = { colorscheme = { "tokyonight", "habamax" } },
  ui = {
    size = vim.env.TERMUX_VERSION and { width = 1, height = 1 } or nil,
    wrap = false,
    border = "rounded",
    icons = {
      keys = "󰥻 ",
    },
    custom_keys = {
      ["<leader><space>"] = {
        function(plugin)
          vim.cmd.close()
          LazyVim.pick("files", { cwd = plugin.dir, title = plugin.name })() -- `title` for snacks picker
        end,
        desc = "Find Plugin File",
      },
      ["<leader>/"] = {
        function(plugin)
          vim.cmd.close()
          LazyVim.pick("live_grep", { cwd = plugin.dir, title = plugin.name })()
        end,
        desc = "Search Plugin Code",
      },
      ["gx"] = {
        function(plugin)
          U.open_in_browser(plugin.url:gsub("%.git$", ""))
        end,
        desc = "Plugin Repo",
      },
      ["gi"] = {
        function(plugin)
          local url = plugin.url:gsub("%.git$", "")
          local line = vim.api.nvim_get_current_line()
          local issue = line:match("#(%d+)")
          local commit = line:match("%f[%w](" .. string.rep("[a-f0-9]", 7) .. ")%f[%W]")
          if issue then
            U.open_in_browser(url .. "/issues/" .. issue)
          elseif commit then
            U.open_in_browser(url .. "/commit/" .. commit)
          end
        end,
        desc = "Open Issue / Commit",
      },
      ["<c-space>"] = {
        function(plugin)
          U.terminal(nil, { win = { position = "float" }, cwd = plugin.dir })
        end,
        desc = "Snacks Terminal (Plugin Dir)",
      },
      ["<localleader>d"] = {
        function(plugin)
          dd(plugin)
        end,
        desc = "Inspect Plugin (Snacks Debug)",
      },
    },
  },
  diff = { cmd = "terminal_git_ignore_all_space" }, -- terminal_git
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
    -- concurrency = vim.env.TERMUX_VERSION and 1 or nil,
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        "netrwPlugin", -- using oil.nvim
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- HACK: add `--ignore-all-space`
-- see: https://github.com/folke/lazy.nvim/blob/6ca90a21202808796418e46d3cebfbb5a44e54a2/lua/lazy/view/init.lua#L287
-- copied from: https://github.com/folke/lazy.nvim/blob/a32e307981519a25dd3f05a33a6b7eea709f0fdc/lua/lazy/view/diff.lua#L49-L61
---@type LazyDiffFun
require("lazy.view.diff").handlers.terminal_git_ignore_all_space = function(plugin, diff)
  local cmd = { "git" }
  if diff.commit then
    cmd[#cmd + 1] = "show"
    cmd[#cmd + 1] = "--ignore-all-space"
    cmd[#cmd + 1] = diff.commit
  else
    cmd[#cmd + 1] = "diff"
    cmd[#cmd + 1] = "--ignore-all-space"
    cmd[#cmd + 1] = diff.from
    cmd[#cmd + 1] = diff.to
  end
  require("lazy.util").float_term(cmd, { cwd = plugin.dir, interactive = false, env = { PAGER = "cat" } })
end
