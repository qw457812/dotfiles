if not LazyVim.has("telescope.nvim") then
  return {}
end

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
    dependencies = { "nvim-telescope/telescope.nvim" },
    event = "LspAttach",
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
  },
  -- {
  --   "aznhe21/actions-preview.nvim",
  --   dependencies = { "nvim-telescope/telescope.nvim" },
  --   event = "LspAttach",
  --   opts = function()
  --     return {
  --       highlight_command = {
  --         require("actions-preview.highlight").delta(),
  --       },
  --       telescope = telescope_opts,
  --     }
  --   end,
  -- },
  {
    "neovim/nvim-lspconfig",
    opts = function()
      local function code_action()
        require("tiny-code-action").code_action()
        -- require("actions-preview").code_actions()
      end

      local Keys = require("lazyvim.plugins.lsp.keymaps").get()
      table.insert(
        Keys,
        { "<leader>ca", code_action, desc = "Code Action Preview", mode = { "n", "v" }, has = "codeAction" }
      )
    end,
  },

  {
    "kosayoda/nvim-lightbulb",
    event = "LspAttach",
    opts = {
      autocmd = { enabled = true },
      sign = { text = "" },
      action_kinds = { "quickfix", "refactor" },
      ignore = {
        clients = { "null-ls", "marksman" },
        actions_without_kind = true,
      },
    },
  },
}
