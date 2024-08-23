if not LazyVim.has_extra("lang.python") then
  return {}
end

-- local ruff = vim.g.lazyvim_python_ruff or "ruff"
local has_black = LazyVim.has_extra("formatting.black")

return {
  -- https://github.com/LazyVim/LazyVim/issues/1819
  -- https://docs.astral.sh/ruff/editors/setup/#neovim
  --
  -- https://github.com/VTantillo/lazyvim/blob/c0483343983da2da16261d2b6bab1bbd9e6a1922/lua/plugins/python.lua#L19
  -- https://github.com/yujinyuz/dotfiles/blob/afe5e42ad59f7b53d829ba612e71ed34673a6130/dot_config/nvim/lua/my/plugins/lspconfig.lua
  -- https://github.com/horta/nvim/blob/f12aa915aadffe82eb5fa9ff635e2835a5d63ad1/lua/plugins/python.lua#L15
  --
  -- https://github.com/jacquin236/minimal-nvim/blob/11f4bc2c82da3f84b5a29266db9bdb09962bca24/lua/plugins/lang/python.lua
  -- https://github.com/aaronlifton/.config/blob/0a60c13c51c3dd102d0f8770f02b1822acb1bb92/.config/nvim/lua/plugins/extras/lang/python-extended.lua
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = {
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
            basedpyright = {
              disableOrganizeImports = true, -- using ruff
              -- https://github.com/DetachHead/basedpyright/issues/203
              typeCheckingMode = "off", -- using ruff
              -- analysis = {
              --   diagnosticSeverityOverrides = {
              --     reportUnusedCallResult = "information",
              --     reportUnusedExpression = "information",
              --     reportUnknownMemberType = "none",
              --     reportUnknownLambdaType = "none",
              --     reportUnknownParameterType = "none",
              --     reportMissingParameterType = "none",
              --     reportUnknownVariableType = "none",
              --     reportUnknownArgumentType = "none",
              --     reportAny = "none",
              --   },
              -- },
            },
          },
        },
        pyright = {
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
            -- verboseOutput = true,
            -- autoImportCompletion = true,
            python = {
              analysis = {
                ignore = { "*" }, -- using ruff
                -- diagnosticSeverityOverrides = {
                --   reportWildcardImportFromLibrary = "none",
                --   reportUnusedImport = "information",
                --   reportUnusedClass = "information",
                --   reportUnusedFunction = "information",
                -- },
                -- typeCheckingMode = "strict",
                -- autoSearchPaths = true,
                -- useLibraryCodeForTypes = true,
                -- diagnosticMode = "openFilesOnly",
                -- indexing = true,
              },
            },
          },
        },
        -- [ruff] = {
        --   handlers = {
        --     ["textDocument/publishDiagnostics"] = function() end,
        --   },
        -- },
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
    "MeanderingProgrammer/py-requirements.nvim",
    event = "BufRead requirements.txt",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
          table.insert(opts.ensure_installed, "requirements")
        end,
      },
      {
        "hrsh7th/nvim-cmp",
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

  -- note that LazyVim use the new "regexp" branch: https://github.com/linux-cultist/venv-selector.nvim/tree/regexp
  {
    "linux-cultist/venv-selector.nvim",
    optional = true,
    -- TODO: temporary fix: venv-selector does not work with extras.editor.fzf
    -- - https://github.com/LazyVim/LazyVim/issues/3612
    -- - https://github.com/linux-cultist/venv-selector.nvim/issues/142
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      settings = {
        options = {
          on_telescope_result_callback = function(filename)
            return require("util.path").replace_home_with_tilde(filename):gsub("/bin/python", "")
          end,
        },
      },
    },
  },

  -- TODO: get the debugpy path from $VIRTUAL_ENV, then fallback to mason?
  -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L32
  -- https://github.com/LazyVim/LazyVim/pull/1031#discussion_r1251566896
}
