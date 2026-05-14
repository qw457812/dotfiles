return {
  -- https://github.com/LazyVim/LazyVim/pull/4133
  -- https://writewithharper.com/docs/integrations/neovim
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        harper_ls = {
          settings = {
            ["harper-ls"] = {
              codeActions = {
                forceStable = true,
              },
              linters = {
                spelled_numbers = true,
                linking_verbs = true,
                sentence_capitalization = false,
              },
            },
          },
        },
      },
    },
  },
}
