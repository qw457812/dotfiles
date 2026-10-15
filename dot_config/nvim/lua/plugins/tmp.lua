local orig_java_home = vim.env.JAVA_HOME -- may be set by Mise
local java_home = vim.g.user_is_termux and "/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk"
  or vim.fn.expand("$HOME/.local/share/mise/installs/java/23")

local proxy = {
  http = "http://127.0.0.1:10808",
  https = "http://127.0.0.1:10808",
  all = "socks5://127.0.0.1:10808",
  no = "localhost,127.0.0.1",
  node_use_env = "1",
}

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
  { "LazyVim/starter", name = "LazyVim-starter", lazy = true, config = function() end },

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
  --   "esmuellert/codediff.nvim",
  --   enabled = not vim.g.user_is_termux,
  --   dependencies = "MunifTanjim/nui.nvim",
  --   cmd = "CodeDiff",
  --   opts = {
  --     -- wait for: https://github.com/esmuellert/codediff.nvim/issues/211
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

  {
    "LazyVim/LazyVim",
    opts = function()
      -- tmux 3.8 can wait 500ms for bare Esc while an unanswered size query is pending.
      -- Size queries were introduced in https://github.com/tmux/tmux/issues/4099;
      -- https://github.com/tmux/tmux/commit/418ddada23d290ab02417b62213b402a08f4d9b5
      -- added pending size queries to the 500ms delay guard (fixing #5388).
      -- Send an explicit CSI-u Escape only to terminals whose job is tmux,
      -- including Sidekick's embedded tmux clients (not shell jobs running tmux attach).
      vim.api.nvim_create_autocmd("TermOpen", {
        group = vim.api.nvim_create_augroup("tmux_terminal_escape", { clear = true }),
        callback = function(event)
          local buf = event.buf
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            local job = vim.b[buf].terminal_job_id
            local argv = job and vim.api.nvim_get_chan_info(job).argv
            if not argv or vim.fn.fnamemodify(argv[1] or "", ":t") ~= "tmux" then
              return
            end
            vim.keymap.set("t", "<Esc>", function()
              vim.api.nvim_chan_send(job, "\27[27;1u")
            end, { buffer = buf, nowait = true, desc = "Send unambiguous Escape to tmux" })
          end)
        end,
      })
    end,
  },

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
    ---@module "spring_boot"
    ---@type bootls.Config|{}
    opts = {
      java_cmd = java_home .. "/bin/java",
    },
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
      -- For (in favor of pantran.nvim, etc.):
      -- 1. kitty.conf
      --    - scrollback_pager nvim --cmd "lua vim.g.terminal_scrollback_pager = true" -c "lua require('util.terminal').kitty_scrollback_pager(INPUT_LINE_NUMBER, CURSOR_LINE, CURSOR_COLUMN)"
      --    - mikesmithgh/kitty-scrollback.nvim
      -- 2. neovide
      if vim.g.terminal_scrollback_pager or vim.g.neovide then
        vim.env.http_proxy = vim.env.http_proxy or proxy.http
        vim.env.HTTP_PROXY = vim.env.HTTP_PROXY or proxy.http
        vim.env.https_proxy = vim.env.https_proxy or proxy.https
        vim.env.HTTPS_PROXY = vim.env.HTTPS_PROXY or proxy.https
        vim.env.all_proxy = vim.env.all_proxy or proxy.all
        vim.env.ALL_PROXY = vim.env.ALL_PROXY or proxy.all
        vim.env.no_proxy = vim.env.no_proxy or proxy.no
        vim.env.NO_PROXY = vim.env.NO_PROXY or proxy.no
        vim.env.NODE_USE_ENV_PROXY = vim.env.NODE_USE_ENV_PROXY or proxy.node_use_env
      end
    end,
  },

  {
    "folke/sidekick.nvim",
    optional = true,
    ---@module "sidekick"
    ---@param opts sidekick.Config
    opts = function(_, opts)
      local proxy_env = vim.g.user_is_termux and {}
        or {
          http_proxy = vim.env.http_proxy or proxy.http,
          HTTP_PROXY = vim.env.HTTP_PROXY or proxy.http,
          https_proxy = vim.env.https_proxy or proxy.https,
          HTTPS_PROXY = vim.env.HTTPS_PROXY or proxy.https,
          all_proxy = vim.env.all_proxy or proxy.all,
          ALL_PROXY = vim.env.ALL_PROXY or proxy.all,
          no_proxy = vim.env.no_proxy or proxy.no,
          NO_PROXY = vim.env.NO_PROXY or proxy.no,
          NODE_USE_ENV_PROXY = vim.env.NODE_USE_ENV_PROXY or proxy.node_use_env,
        }

      return U.extend_tbl(opts, {
        cli = {
          ---@type table<string, sidekick.cli.Config|{}>
          tools = {
            pi = {
              -- needed for openai-codex to login/refreshToken even with TUN on
              -- https://github.com/earendil-works/pi/issues/1132
              env = proxy_env,
            },
            dsh = {
              env = proxy_env,
            },
          },
        },
      } --[[@as sidekick.Config]])
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(ev)
          vim.diagnostic.enable(false, { bufnr = ev.buf })
        end,
      })
    end,
  },

  -- TODO: breaking changes
  -- `textobjects.scm` query files with `nvim-treesitter/nvim-treesitter-textobjects`
  { "chrisgrieser/nvim-various-textobjs", optional = true, commit = "bf2133a" },

  -- TODO: breaking changes
  -- v3 moves multiplexers into backend plugins and drops the Herdr backend
  -- https://github.com/mrjones2014/smart-splits.nvim/issues/488
  -- pin v2 for now
  { "mrjones2014/smart-splits.nvim", optional = true, commit = "ec76708" },
}
