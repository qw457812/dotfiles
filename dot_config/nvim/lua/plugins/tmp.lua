local java_home = vim.g.user_is_termux and "/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk"
  or vim.fn.expand("$HOME/.local/share/mise/installs/java/23")

---@type LazySpec
return {
  {
    "neovim/neovim",
    pin = true,
    enabled = function()
      local v = vim.version()
      return v and v.prerelease ~= nil -- nightly
    end,
    lazy = true,
    config = function() end,
    specs = {
      {
        "LazyVim/LazyVim",
        keys = {
          {
            "<leader>ln",
            function()
              vim.cmd("Lazy log neovim")
              vim.defer_fn(function()
                vim.cmd("silent! /neovim")
              end, 200)
            end,
            desc = "Neovim Logs",
          },
        },
      },
    },
  },

  -- -- dummy import
  -- {
  --   import = "foobar",
  --   enabled = function()
  --     -- something can be done here
  --     return false
  --   end,
  -- },

  {
    "alex-popov-tech/store.nvim",
    enabled = not vim.g.user_is_termux, -- error on termux
    cmd = "Store",
    keys = {
      { "<leader>lh", "<cmd>Store<cr>", desc = "Plugin Hub" },
    },
    ---@module "store"
    ---@type UserConfig
    opts = {
      width = 0.95,
      height = 0.9,
      keybindings = {
        hover = { "gk" },
      },
    },
  },

  -- for java projects using JDK version older than 21
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.cmd, "--java-executable=" .. java_home .. "/bin/java")
    end,
  },
  -- for scala projects using JDK version older than 21
  {
    "neovim/nvim-lspconfig",
    opts = function()
      if not LazyVim.has_extra("lang.scala") then
        return
      end
      -- see: https://github.com/scalameta/nvim-metals/issues/380
      vim.env.JAVA_HOME = java_home
    end,
  },

  -- vim-dadbod
  {
    "LazyVim/LazyVim",
    opts = function()
      -- The OceanBase I am using does not work with MySQL >9.0
      vim.env.PATH = "/opt/homebrew/opt/mysql@8.4/bin:" .. vim.env.PATH

      U.sql.add_dbs_to_dadbod_ui({
        mysql = {
          { name = "mysql_local", user = "root", password = "root" },
        },
      })
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = function()
      -- for kitty.conf: scrollback_pager nvim --cmd "lua vim.g.terminal_scrollback_pager = true" -c "lua require('util.terminal').colorize()"
      -- in favor of pantran.nvim
      if vim.g.terminal_scrollback_pager then
        do
          return -- using TUN for now
        end
        vim.env.https_proxy = "http://127.0.0.1:10808"
        vim.env.http_proxy = "http://127.0.0.1:10808"
        vim.env.all_proxy = "socks5://127.0.0.1:10808"
      end
    end,
  },

  -- TODO: breaking changes
  { "chrisgrieser/nvim-various-textobjs", optional = true, commit = "bf2133a" },
}
