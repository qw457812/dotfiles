if not LazyVim.has_extra("lang.clojure") then
  return {}
end

-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/pack/clojure
---@type LazySpec
return {
  -- lazy loading
  {
    "m00qek/baleia.nvim",
    optional = true,
    lazy = true,
  },
  {
    "julienvincent/nvim-paredit",
    optional = true,
    event = function()
      return {}
    end,
    ft = {
      "clojure",
      -- "fennel",
      -- "scheme",
      -- "lisp",
      -- "janet",
    },
  },
  {
    "Olical/conjure",
    optional = true,
    event = function()
      return {}
    end,
    ft = {
      "clojure",
      -- "janet",
      -- "fennel",
      -- "racket",
      -- "hy",
      -- "scheme",
      -- "guile",
      -- "julia",
      -- "lua",
      -- "lisp",
      -- "rust",
      -- "sql",
      -- "python",
    },
  },

  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        clojure = { "joker" },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = not vim.g.user_is_asahi and { "joker" } or nil,
    },
  },

  -- {
  --   "neovim/nvim-lspconfig",
  --   opts = {
  --     servers = {
  --       clojure_lsp = {},
  --     },
  --   },
  -- },
}
