local telescope_opts = {
  layout_strategy = "vertical",
  layout_config = {
    preview_cutoff = 1,
    vertical = {
      preview_height = function(_, _, max_lines)
        return math.max(max_lines - 15, math.floor(max_lines * 0.6))
      end,
    },
  },
}

return {
  {
    "rachartier/tiny-code-action.nvim",
    enabled = function()
      return LazyVim.has("telescope.nvim")
    end,
    lazy = true,
    -- event = "LspAttach",
    opts = {
      backend = "delta",
      backend_opts = {
        delta = {
          args = {
            "--line-numbers",
            -- see: ~/.gitconfig
            "--diff-so-fancy",
            '--minus-emph-style="reverse red"',
            '--plus-emph-style="reverse green"',
            '--hunk-header-style="line-number syntax"',
          },
        },
      },
      telescope_opts = telescope_opts,
    },
    specs = {
      {
        "neovim/nvim-lspconfig",
        opts = function()
          local Keys = require("lazyvim.plugins.lsp.keymaps").get()
          table.insert(Keys, {
            "<leader>ca",
            function()
              require("tiny-code-action").code_action({})
            end,
            desc = "Code Action Preview",
            mode = { "n", "v" },
            has = "codeAction",
          })
        end,
      },
    },
  },

  {
    "aznhe21/actions-preview.nvim",
    enabled = function()
      return LazyVim.has("telescope.nvim")
    end,
    lazy = true,
    -- event = "LspAttach *.java",
    opts = function()
      return {
        highlight_command = {
          require("actions-preview.highlight").delta(),
        },
        telescope = telescope_opts,
      }
    end,
    specs = {
      {
        "neovim/nvim-lspconfig",
        opts = function()
          local Keys = require("lazyvim.plugins.lsp.keymaps").get()
          table.insert(Keys, {
            "<leader>ca",
            function()
              require("actions-preview").code_actions()
            end,
            desc = "Code Action Preview",
            mode = { "n", "v" },
            has = "codeAction",
            ft = "java", -- tiny-code-action.nvim failed to run "Generate toString()..." from jdtls
          })
        end,
      },
    },
  },

  {
    "ibhagwan/fzf-lua",
    optional = true,
    specs = {
      {
        "neovim/nvim-lspconfig",
        opts = function()
          local Keys = require("lazyvim.plugins.lsp.keymaps").get()
          table.insert(Keys, {
            "<leader>ca",
            "<cmd>FzfLua lsp_code_actions<cr>",
            desc = "Code Action Preview",
            mode = { "n", "v" },
            has = "codeAction",
          })
        end,
      },
    },
  },

  {
    "kosayoda/nvim-lightbulb",
    event = "LspAttach",
    opts = {
      autocmd = { enabled = true },
      sign = { text = "" },
      action_kinds = { "quickfix", "refactor" },
      ignore = {
        clients = { "null-ls", "lua_ls" },
        actions_without_kind = true,
      },
    },
  },
}
