if not LazyVim.has_extra("lang.python") then
  return {}
end

local ruff = vim.g.lazyvim_python_ruff or "ruff"

return {
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

  -- isort
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "isort",
        "debugpy", -- required by nvim-dap-python
      },
    },
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.isort)
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      if LazyVim.has_extra("formatting.black") then
        opts.formatters_by_ft = opts.formatters_by_ft or {}
        -- run multiple formatters sequentially
        -- TODO: ruff_format, ruff_organize_imports, ruff_fix?
        -- https://github.com/stevearc/conform.nvim#options
        -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L156
        opts.formatters_by_ft.python = { "isort", "black" }
      end
    end,
  },

  -- TODO: get the debugpy path from $VIRTUAL_ENV, then fallback to mason?
  -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L32
  -- https://github.com/LazyVim/LazyVim/pull/1031#discussion_r1251566896

  -- TODO: mfussenegger/nvim-lint: mypy?
  -- https://github.com/akthe-at/.dotfiles/blob/49beab5ec32659fba8f3b0c5ca3a6f75cc7a7d8a/nvim/lua/plugins/lint.lua
  -- https://github.com/fredrikaverpil/dotfiles/blob/be037d3e442b25d356f0bdd18ac2a17c346d71aa/nvim-fredrik/lua/lang/python.lua#L177

  -- https://github.com/jacquin236/minimal-nvim/blob/11f4bc2c82da3f84b5a29266db9bdb09962bca24/lua/plugins/lang/python.lua
  -- https://github.com/aaronlifton/.config/blob/0a60c13c51c3dd102d0f8770f02b1822acb1bb92/.config/nvim/lua/plugins/extras/lang/python-extended.lua
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                diagnosticSeverityOverrides = {
                  reportUnusedCallResult = "information",
                  reportUnusedExpression = "information",
                  reportUnknownMemberType = "none",
                  reportUnknownLambdaType = "none",
                  reportUnknownParameterType = "none",
                  reportMissingParameterType = "none",
                  reportUnknownVariableType = "none",
                  reportUnknownArgumentType = "none",
                  reportAny = "none",
                },
              },
            },
          },
        },
        pyright = {
          settings = {
            verboseOutput = true,
            autoImportCompletion = true,
            python = {
              analysis = {
                diagnosticSeverityOverrides = {
                  reportWildcardImportFromLibrary = "none",
                  reportUnusedImport = "information",
                  reportUnusedClass = "information",
                  reportUnusedFunction = "information",
                },
                typeCheckingMode = "strict",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
                indexing = true,
              },
            },
          },
        },
        [ruff] = {
          handlers = {
            ["textDocument/publishDiagnostics"] = function() end,
          },
        },
      },
      setup = {
        [ruff] = function()
          LazyVim.lsp.on_attach(function(client, _)
            client.server_capabilities.hoverProvider = false
            -- Added this line so basedpyright is the only diagnoistics provider
            client.server_capabilities.diagnosticProvider = false
          end, ruff)
        end,
      },
    },
  },

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
}
