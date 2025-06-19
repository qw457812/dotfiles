local java_home = vim.g.user_is_termux and "/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk"
  or vim.fn.expand("$HOME/.local/share/mise/installs/java/23")

return {
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

  -- :echo db#url#encode('my_password')
  -- :=vim.fn['db#url#encode']('my_password')
  -- :echo db#url#parse('my_url')
  -- :echo db#adapter#dispatch("my_url", "interactive")
  {
    "tpope/vim-dadbod",
    optional = true,
    init = function()
      -- -- The OceanBase I am using does not work with MySQL >9.0
      -- vim.env.PATH = "/opt/homebrew/opt/mysql@8.4/bin:" .. vim.env.PATH

      local url = {
        mysql = function(user, password, host, port, database)
          -- mysql://[<user>[:<password>]@][<host>[:<port>]]/[database]
          return string.format(
            "mysql://%s:%s@%s:%s/%s",
            U.url_encode(user),
            U.url_encode(password),
            host,
            port,
            database
          )
        end,
      }

      -- https://github.com/kristijanhusak/vim-dadbod-ui#via-gdbs-global-variable
      vim.g.dbs = vim.list_extend(vim.g.dbs or {}, {
        {
          name = "mysql_local",
          url = url.mysql("root", "root", "localhost", "3306", ""),
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
        vim.env.https_proxy = "http://127.0.0.1:10808"
        vim.env.http_proxy = "http://127.0.0.1:10808"
        vim.env.all_proxy = "socks5://127.0.0.1:10808"
      end
    end,
  },

  { "zapling/mason-lock.nvim", optional = true, commit = "86614f7" },

  -- TODO: breaking changes
  { "chrisgrieser/nvim-various-textobjs", optional = true, commit = "bf2133a" },
}
