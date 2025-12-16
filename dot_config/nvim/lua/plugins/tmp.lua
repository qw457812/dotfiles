local orig_java_home = vim.env.JAVA_HOME -- may be set by Mise
local java_home = vim.g.user_is_termux and "/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk"
  or vim.fn.expand("$HOME/.local/share/mise/installs/java/23")

---@type LazySpec
return {
  {
    "neovim/neovim",
    pin = true,
    -- commit = "",
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

  -- {
  --   "esmuellert/vscode-diff.nvim",
  --   dependencies = "MunifTanjim/nui.nvim",
  --   cmd = "CodeDiff",
  --   opts = {
  --     keymaps = {
  --       view = {
  --         next_hunk = "]h",
  --         prev_hunk = "[h",
  --         next_file = "J",
  --         prev_file = "K",
  --       },
  --       explorer = {
  --         hover = "gk",
  --       },
  --     },
  --   },
  -- },

  -- for java projects using JDK version older than 21, 1.8 in my case
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.cmd, "--java-executable=" .. java_home .. "/bin/java")
    end,
  },
  {
    "JavaHello/spring-boot.nvim",
    optional = true,
    opts = function()
      -- HACK: better alternative to `vim.env.JAVA_HOME = java_home`
      -- https://github.com/JavaHello/spring-boot.nvim/blob/2bc14e114f748ebba365641b38403c9819cd42cd/lua/spring_boot/util.lua#L22-L28
      ---@diagnostic disable-next-line: duplicate-set-field
      require("spring_boot.util").java_bin = function()
        return java_home .. "/bin/java"
      end
    end,
  },
  {
    "folke/sidekick.nvim",
    optional = true,
    ---@module "sidekick"
    ---@param opts sidekick.Config
    opts = function(_, opts)
      opts.cli = opts.cli or {}
      for _, tool in pairs(opts.cli.tools or {}) do
        -- Use the JAVA_HOME set by Mise. Otherwise, `mvn clean compile` in Claude Code's Bash tool will fail for some Java 1.8 projects.
        -- Run `! mvn -v` in Claude Code to confirm.
        -- https://github.com/folke/sidekick.nvim/blob/83b6815c0ed738576f101aad31c79b885c892e0f/lua/sidekick/cli/terminal.lua#L272C45-L272C64
        tool.env = U.extend_tbl({ JAVA_HOME = orig_java_home }, tool.env)
      end
    end,
  },
  -- for scala projects using JDK version older than 21, 1.8 in my case
  -- (Oracle SQLcl requires Java 11 and above to run, see vim.g.dbext_default_ORA_bin of vim-dadbod)
  {
    "neovim/nvim-lspconfig",
    opts = function()
      if LazyVim.has_extra("lang.scala") then
        -- see: https://github.com/scalameta/nvim-metals/issues/380
        vim.env.JAVA_HOME = java_home
      end
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
          mysql_local = { user = "root", password = "root" },
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
  --
  -- migrate to v18:
  -- * https://github.com/olimorris/codecompanion.nvim/pull/2439
  -- * https://github.com/olimorris/codecompanion.nvim/discussions/2465
  { "olimorris/codecompanion.nvim", optional = true, commit = "8ad65ee" },
  { "ravitemer/codecompanion-history.nvim", lazy = true, optional = true, commit = "eb99d25" },
  --
  -- `textobjects.scm` query files with `nvim-treesitter/nvim-treesitter-textobjects`
  { "chrisgrieser/nvim-various-textobjs", optional = true, commit = "bf2133a" },
}
