return {
  {
    "kovidgoyal/kitty",
    version = "*",
    cond = vim.g.user_is_kitty,
    lazy = true,
    config = function() end,
    specs = {
      -- alternative: pyrightconfig.json or pyproject.toml
      {
        "neovim/nvim-lspconfig",
        opts = {
          servers = {
            basedpyright = {
              settings = {
                basedpyright = {
                  analysis = {
                    extraPaths = { require("lazy.core.config").options.root .. "/kitty" },
                  },
                },
              },
            },
            pyright = {
              settings = {
                python = {
                  analysis = {
                    extraPaths = { require("lazy.core.config").options.root .. "/kitty" },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}
