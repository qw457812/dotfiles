if not LazyVim.has_extra("lang.clojure") then
  return {}
end

-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/pack/clojure
return {
  -- lazy loading
  {
    "m00qek/baleia.nvim",
    optional = true,
    lazy = true,
  },
  {
    "PaterJason/nvim-treesitter-sexp",
    optional = true,
    event = function()
      return {}
    end,
    ft = {
      "clojure",
      -- "fennel",
      -- "janet",
      -- "query",
    },
    cmd = "TSSexp",
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
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "joker",
        -- "clj-kondo",
      },
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

  -- {
  --   "mfussenegger/nvim-lint",
  --   optional = true,
  --   opts = {
  --     linters_by_ft = {
  --       clojure = { "clj-kondo" },
  --     },
  --   },
  -- },
}
