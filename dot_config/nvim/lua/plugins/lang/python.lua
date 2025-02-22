if not LazyVim.has_extra("lang.python") then
  return {}
end

local lsp = vim.g.lazyvim_python_lsp or "pyright"
-- local ruff = vim.g.lazyvim_python_ruff or "ruff"
local has_black = LazyVim.has_extra("formatting.black")

return {
  -- https://github.com/LazyVim/LazyVim/issues/1819
  -- https://docs.astral.sh/ruff/editors/setup/#neovim
  --
  -- https://github.com/VTantillo/lazyvim/blob/c0483343983da2da16261d2b6bab1bbd9e6a1922/lua/plugins/python.lua#L19
  -- https://github.com/yujinyuz/dotfiles/blob/afe5e42ad59f7b53d829ba612e71ed34673a6130/dot_config/nvim/lua/my/plugins/lspconfig.lua
  -- https://github.com/horta/nvim/blob/f12aa915aadffe82eb5fa9ff635e2835a5d63ad1/lua/plugins/python.lua#L15
  -- https://github.com/a1401358759/TurboNvim/blob/1dc06655e998d560d0238f30465b3d58c083c506/lua/lspservers/basedpyright.lua
  -- https://github.com/a1401358759/TurboNvim/blob/1dc06655e998d560d0238f30465b3d58c083c506/lua/lspservers/ruff.lua
  --
  -- https://github.com/aaronlifton/.config/blob/0a60c13c51c3dd102d0f8770f02b1822acb1bb92/.config/nvim/lua/plugins/extras/lang/python-extended.lua
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#basedpyright
        -- https://docs.basedpyright.com/#/settings
        -- https://docs.basedpyright.com/#/configuration
        -- https://github.com/DetachHead/basedpyright/blob/main/packages/vscode-pyright/package.json
        basedpyright = {
          settings = {
            basedpyright = {
              disableOrganizeImports = true, -- using ruff
              analysis = {
                -- https://github.com/DetachHead/basedpyright/issues/203
                -- typeCheckingMode = "off", -- using ruff
                typeCheckingMode = "standard", -- off, basic, standard, strict, all(default)
                -- -- https://github.com/detachhead/basedpyright/blob/main/docs/configuration.md#diagnostic-settings-defaults
                -- diagnosticSeverityOverrides = {},
              },
            },
          },
        },
        -- https://github.com/microsoft/pyright/blob/main/packages/vscode-pyright/package.json
        pyright = {
          -- -- TODO: not sure what it's for
          -- capabilities = {
          --   textDocument = {
          --     publishDiagnostics = {
          --       tagSupport = {
          --         valueSet = { 2 },
          --       },
          --     },
          --   },
          -- },
          settings = {
            pyright = {
              disableOrganizeImports = true, -- using ruff
            },
            python = {
              analysis = {
                -- ignore = { "*" }, -- using ruff
                typeCheckingMode = "standard", -- off, basic, standard(default), strict
                -- -- https://github.com/microsoft/pyright/blob/main/docs/configuration.md#diagnostic-settings-defaults
                -- diagnosticSeverityOverrides = {},
              },
            },
          },
        },
        ruff = {
          mason = not vim.g.user_is_termux and nil, -- run `pkg install ruff` on termux
          -- -- -- TODO: not sure what it's for
          -- -- handlers = {
          -- --   ["textDocument/publishDiagnostics"] = function() end,
          -- -- },
          -- init_options = {
          --   settings = {
          --     -- https://docs.astral.sh/ruff/editors/settings/#ignore
          --     lint = {
          --       -- https://github.com/DetachHead/basedpyright/issues/203
          --       -- https://github.com/DetachHead/basedpyright/blob/06368d488b93c0378520067546b286c0b4f5472c/pyproject.toml#L218
          --       extendSelect = { "ALL" },
          --       -- stylua: ignore
          --       ignore = {
          --         "ANN",     -- flake8-annotations (covered by pyright)
          --         "EM",      -- flake8-errmsg
          --         "FIX",     -- flake8-fixme
          --         "PLR0913", -- Too many arguments to function call
          --         "PLR0912", -- Too many branches
          --         "PLR0915", -- Too many statements
          --         "PLR2004", -- Magic value used in comparison
          --         "PLR1722", -- Use `sys.exit()` instead of `exit`
          --         "PLW2901", -- `for` loop variable overwritten by assignment target
          --         "PLE0605", -- Invalid format for `__all__`, must be `tuple` or `list` (covered by pyright)
          --         "PLR0911", -- Too many return statements
          --         "PLW0603", -- Using the global statement is discouraged
          --         "PLC0105", -- `TypeVar` name does not reflect its covariance
          --         "PLC0414", -- Import alias does not rename original package (used by pyright for explicit re-export)
          --         "RUF013",  -- PEP 484 prohibits implicit Optional (covered by pyright)
          --         "RUF016",  -- Slice in indexed access to type (covered by pyright)
          --         "TRY002",  -- Create your own exception
          --         "TRY003",  -- Avoid specifying long messages outside the exception class
          --         "D10",     -- Missing docstring
          --         "D203",    -- 1 blank line required before class docstring
          --         "D205",    -- 1 blank line required between summary line and description
          --         "D209",    -- Multi-line docstring closing quotes should be on a separate line
          --         "D212",    -- Multi-line docstring summary should start at the first line
          --         "D213",    -- Multi-line docstring summary should start at the second line
          --         "D400",    -- First line should end with a period
          --         "D401",    -- First line should be in imperative mood
          --         "D403",    -- First word of the first line should be properly capitalized
          --         "D404",    -- First word of the docstring should not be `This`
          --         "D405",    -- Section name should be properly capitalized
          --         "D406",    -- Section name should end with a newline
          --         "D415",    -- First line should end with a period, question mark, or exclamation point
          --         "D418",    -- Function/Method decorated with @overload shouldn't contain a docstring (vscode supports it)
          --         "PT013",   -- Found incorrect import of pytest, use simple import pytest instead (only for bad linters that can't check the qualname)
          --         "TD002",   -- Missing author in TODO
          --         "CPY001",  -- missing-copyright-notice
          --         "C901",    -- max-complexity
          --         "ISC001",  -- single-line-implicit-string-concatenation (conflicts with formatter)
          --         "COM812",  -- missing-trailing-comma (conflicts with formatter)
          --       },
          --     },
          --   },
          -- },
        },
      },
      -- setup = {
      --   [ruff] = function()
      --     LazyVim.lsp.on_attach(function(client, _)
      --       client.server_capabilities.hoverProvider = false
      --       -- Added this line so basedpyright is the only diagnoistics provider
      --       client.server_capabilities.diagnosticProvider = false
      --     end, ruff)
      --   end,
      -- },
    },
  },

  -- fix: diagnostic for python is not enabled on startup
  {
    "neovim/nvim-lspconfig",
    opts = function()
      if lsp == "basedpyright" then
        LazyVim.lsp.on_attach(function()
          vim.schedule(function()
            Snacks.toggle.diagnostics():set(true)
          end)
          ---@diagnostic disable-next-line: redundant-return-value
          return true -- don't mess up toggle
        end, lsp)
      end
    end,
  },

  -- (isort + black) or ruff
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "debugpy") -- required by nvim-dap-python
      if has_black then
        table.insert(opts.ensure_installed, "isort")
      end
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      if has_black then
        local nls = require("null-ls")
        opts.sources = opts.sources or {}
        table.insert(opts.sources, nls.builtins.formatting.isort)
      end
    end,
  },
  -- https://github.com/stevearc/conform.nvim#options
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.python = has_black and { "isort", "black" }
        or { "ruff_fix", "ruff_format", "ruff_organize_imports" }
    end,
  },
  -- TODO: mypy?
  -- https://github.com/akthe-at/.dotfiles/blob/49beab5ec32659fba8f3b0c5ca3a6f75cc7a7d8a/nvim/lua/plugins/lint.lua
  -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L177
  -- {
  --   "mfussenegger/nvim-lint",
  --   opts = {
  --     linters_by_ft = {
  --       python = { "ruff" }, -- duplicate diagnostics with Ruff LSP
  --     },
  --   },
  -- },

  {
    "linux-cultist/venv-selector.nvim",
    optional = true,
    opts = {
      settings = {
        options = {
          on_telescope_result_callback = function(filename)
            return U.path.home_to_tilde(filename):gsub("/bin/python", "")
          end,
        },
      },
    },
  },

  -- https://github.com/MeanderingProgrammer/dotfiles/blob/3f48b647453dff09b9c9d39bead797082b445175/.config/nvim/lua/mp/plugins/lang/python.lua#L23
  {
    "MeanderingProgrammer/py-requirements.nvim",
    enabled = false, -- TODO: bad performance
    event = "BufRead requirements.txt",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
          table.insert(opts.ensure_installed, "requirements")
        end,
      },
      {
        "nvim-cmp",
        optional = true,
        opts = function(_, opts)
          table.insert(opts.sources, { name = "py-requirements" })
        end,
      },
    },
    opts = {},
    -- stylua: ignore
    keys = {
      { "<leader>Ppu", function() require("py-requirements").upgrade() end, desc = "Update Package" },
      { "<leader>PpU", function() require("py-requirements").upgrade_all() end, desc = "Update All Packages" },
      { "<leader>PpK", function() require("py-requirements").show_description() end, desc = "Show Package Description" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>P", group = "packages/dependencies", icon = " " },
        { "<leader>Pp", group = "python", icon = " " },
      },
    },
  },

  -- TODO: get the debugpy path from $VIRTUAL_ENV, then fallback to mason?
  -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L32
  -- https://github.com/LazyVim/LazyVim/pull/1031#discussion_r1251566896
}
