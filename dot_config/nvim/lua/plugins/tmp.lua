local obsidian_vaults = {
  personal = U.path.HOME .. "/Documents/vaults/personal",
  work = U.path.HOME .. "/Documents/vaults/work",
}

-- https://github.com/folke/dot/blob/master/nvim/lua/plugins/tmp.lua
return {
  {
    "yarospace/lua-console.nvim",
    keys = {
      { "<leader>.", desc = "Lua Console" },
    },
    opts = {
      window = {
        border = "rounded",
      },
      mappings = {
        toggle = "<leader>.",
        clear = "<localleader>c",
        messages = "<localleader>m",
        save = "<C-s>",
        load = "<leader>fr",
        help = "g?",
      },
    },
  },

  {
    "2kabhishek/nerdy.nvim",
    cmd = "Nerdy",
    keys = {
      { "<leader>fI", "<cmd>Nerdy<cr>", desc = "Icons" },
    },
  },

  -- :echo db#url#encode('my_password')
  -- :echo db#url#parse('my_url')
  -- :echo db#adapter#dispatch("my_url", "interactive")
  {
    "tpope/vim-dadbod",
    optional = true,
    init = function()
      -- The OceanBase I am using does not work with MySQL >9.0
      vim.env.PATH = "/opt/homebrew/opt/mysql@8.4/bin:" .. vim.env.PATH

      -- :=vim.fn['db#url#encode']('my_password')
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

  {
    "thenbe/csgithub.nvim",
    keys = {
      {
        "<leader>/",
        mode = "x",
        function()
          local csgithub = require("csgithub")
          csgithub.open(csgithub.search())
        end,
        desc = "GitHub Code Search (extension)",
      },
      {
        "<leader>?",
        mode = "x",
        function()
          local csgithub = require("csgithub")
          csgithub.open(csgithub.search({ includeFilename = true }))
        end,
        desc = "GitHub Code Search (filename)",
      },
    },
  },

  -- {
  --   "nvchad/showkeys",
  --   enabled = false,
  --   cmd = "ShowkeysToggle",
  --   opts = {
  --     -- timeout = 1,
  --     maxkeys = 5,
  --     show_count = true,
  --     position = "top-right",
  --   },
  -- },

  -- https://github.com/nvim-orgmode/orgmode/blob/master/DOCS.md#mappings
  -- https://github.com/ales-tsurko/neovim-config/blob/f6d6e86c8d1b545d4de110513e2758edb9a31d6b/lua/extensions/orgmode.lua
  -- https://github.com/milanglacier/nvim/blob/8a7de805a0a79aeb0b2498a804bd00d9fe254d21/lua/plugins/org.lua
  -- https://github.com/vkrit/dotfiles/blob/b090344511c5f5ea02e6a387ce69851be13a5526/dot_config/lvim/config.lua#L94
  -- https://github.com/lukas-reineke/dotfiles/blob/3a1afd9bad999cc2cdde98851c2a5066f60fc193/vim/lua/plugins/org.lua
  -- https://github.com/tobymelin/configs/blob/d65a22add5f5744272c6c46549f21a36f109e80f/nvim/lua/plugins/orgmode.lua#L4
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    keys = {
      { "<leader>o", "", desc = "+orgmode" }, -- TODO: conflict with extras.editor.overseer
    },
    opts = {
      org_agenda_files = "~/org/**/*",
      org_default_notes_file = "~/org/refile.org",
      mappings = {
        -- disable_all = true,

        -- global = {
        --   org_agenda = "gA",
        --   org_capture = "gC",
        -- },

        -- prefix = "<Leader>o",
      },
    },
  },

  {
    "epwalsh/obsidian.nvim",
    -- version = "*",
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

      -- TODO: `:verbose nmap <cr>`, overlaps with "Goto Definition/References" defined in lsp.lua
    end,
  },

  -- {
  --   "akinsho/toggleterm.nvim",
  --   keys = { { "<c-space>" } },
  --   opts = {
  --     open_mapping = "<c-space>",
  --     -- direction = "float",
  --   },
  -- },
  -- -- {
  -- --   "ryanmsnyder/toggleterm-manager.nvim",
  -- --   opts = {},
  -- --   keys = {
  -- --     { "<leader>ft", "<cmd>Telescope toggleterm_manager<cr>", desc = "Terminals" },
  -- --   },
  -- -- },

  -- TODO: not working
  -- -- https://github.com/wlh320/rime-ls
  -- -- https://github.com/wlh320/rime-ls/blob/master/doc/nvim.md
  -- -- https://github.com/liubianshi/cmp-lsp-rimels
  -- {
  --   "liubianshi/cmp-lsp-rimels",
  --   dependencies = {
  --     "neovim/nvim-lspconfig",
  --     "hrsh7th/nvim-cmp",
  --     "hrsh7th/cmp-nvim-lsp",
  --   },
  --   keys = { { "<localleader>f", mode = "i" } },
  --   config = function()
  --     vim.system({ "rime_ls", "--listen", "127.0.0.1:9257" })
  --     require("rimels").setup({
  --       cmd = vim.lsp.rpc.connect("127.0.0.1", 9257),
  --     })
  --   end,
  -- },
}
