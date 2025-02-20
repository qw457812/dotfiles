local obsidian_vaults = {
  personal = U.path.HOME .. "/Documents/vaults/personal",
  work = U.path.HOME .. "/Documents/vaults/work",
}

return {
  {
    "yarospace/lua-console.nvim",
    keys = {
      {
        "<leader>[",
        function()
          local foldcolumn = vim.o.foldcolumn
          require("lua-console").toggle_console()
          if Lua_console.win then
            vim.wo[Lua_console.win].foldcolumn = foldcolumn
          end
        end,
        desc = "Toggle Lua console",
      },
      { "<leader>]", desc = "Attach Lua console to buffer" },
    },
    opts = {
      mappings = {
        toggle = false, -- "<leader>["
        attach = "<leader>]",
        clear = "<localleader>c",
        messages = "<localleader>m",
        save = "<localleader>s",
        load = "<localleader>l",
        help = "g?",
      },
      window = {
        border = "rounded",
      },
    },
  },

  {
    "thenbe/csgithub.nvim",
    keys = function()
      local function search(args)
        local csgithub = require("csgithub")
        local url = csgithub.search(args)
        if url and vim.g.user_is_termux then
          vim.fn.setreg(vim.v.register, url)
          LazyVim.info(url, { title = "Copied URL" })
        else
          csgithub.open(url)
        end
      end

      return {
        { "<leader>/", mode = "x", search, desc = "GitHub Code Search (extension)" },
        {
          "<leader>?",
          mode = "x",
          function()
            search({ includeFilename = true })
          end,
          desc = "GitHub Code Search (filename)",
        },
      }
    end,
  },

  -- :echo db#url#encode('my_password')
  -- :echo db#url#parse('my_url')
  -- :echo db#adapter#dispatch("my_url", "interactive")
  {
    "tpope/vim-dadbod",
    optional = true,
    init = function()
      -- -- The OceanBase I am using does not work with MySQL >9.0
      -- vim.env.PATH = "/opt/homebrew/opt/mysql@8.4/bin:" .. vim.env.PATH

      -- :=vim.fn['db#url#encode']('my_password')
      -- https://github.com/mistweaverco/kulala.nvim/blob/1c4156b8204137ff683d7c61b94218ca1cfbf801/lua/kulala/utils/string.lua#L22
      local url_encode = function(str)
        local function to_hex(char)
          return string.format("%%%02X", string.byte(char))
        end
        return string.gsub(str, "[^a-zA-Z0-9_]", to_hex)
      end

      local url = {
        mysql = function(user, password, host, port, database)
          -- mysql://[<user>[:<password>]@][<host>[:<port>]]/[database]
          return string.format("mysql://%s:%s@%s:%s/%s", url_encode(user), url_encode(password), host, port, database)
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

  -- https://github.com/nvim-orgmode/orgmode/blob/master/DOCS.md#mappings
  {
    "nvim-orgmode/orgmode",
    ft = { "org", "orgagenda" },
    cmd = "Org",
    keys = {
      { "gA", '<Cmd>lua require("orgmode").action("agenda.prompt")<CR>', desc = "org agenda" },
      { "gC", '<Cmd>lua require("orgmode").action("capture.prompt")<CR>', desc = "org capture" },
    },
    opts = {
      org_agenda_files = "~/org/**/*",
      org_default_notes_file = "~/org/refile.org",
      mappings = {
        -- disable_all = true,
        global = {
          org_agenda = false,
          org_capture = false,
        },
        prefix = "<localleader>",
      },
    },
  },

  {
    "epwalsh/obsidian.nvim",
    cond = not vim.g.user_is_termux,
    event = (function()
      local events = {}
      for _, path in pairs(obsidian_vaults) do
        table.insert(events, "BufReadPre " .. path .. "/*.md")
        table.insert(events, "BufNewFile " .. path .. "/*.md")
      end
      return events
    end)(),
    opts = function(_, opts)
      if LazyVim.has("render-markdown.nvim") then
        -- https://github.com/MeanderingProgrammer/render-markdown.nvim#obsidiannvim
        opts.ui = { enable = false }
      end

      opts.workspaces = opts.workspaces or {}
      for name, path in pairs(obsidian_vaults) do
        table.insert(opts.workspaces, { name = name, path = path })
      end
    end,
  },
}
