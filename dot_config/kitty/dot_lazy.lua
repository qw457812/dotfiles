return {
  {
    "kovidgoyal/kitty",
    version = "*",
    cond = vim.g.user_is_kitty,
    lazy = true,
    config = function() end,
    -- extraPaths is configured via pyrightconfig.json instead of nvim-lspconfig
    -- because pyright/basedpyright natively discovers it, so agents (like pi)
    -- that run LSP type checks outside Neovim also benefit
    --
    -- specs = {
    --   {
    --     "neovim/nvim-lspconfig",
    --     opts = {
    --       servers = {
    --         basedpyright = {
    --           settings = {
    --             basedpyright = {
    --               analysis = {
    --                 extraPaths = { require("lazy.core.config").options.root .. "/kitty" },
    --               },
    --             },
    --           },
    --         },
    --         pyright = {
    --           settings = {
    --             python = {
    --               analysis = {
    --                 extraPaths = { require("lazy.core.config").options.root .. "/kitty" },
    --               },
    --             },
    --           },
    --         },
    --       },
    --     },
    --   },
    -- },
  },
}
