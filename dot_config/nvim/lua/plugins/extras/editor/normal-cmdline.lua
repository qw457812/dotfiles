return {
  {
    "jake-stewart/normal-cmdline.nvim",
    event = "CmdlineEnter",
    init = function()
      -- make the cmdline insert mode a beam
      vim.opt.guicursor:append("ci:ver1,c:ver1")
    end,
    opts = {},
    specs = {
      "folke/noice.nvim",
      optional = true,
      opts = {
        cmdline = {
          format = {
            cmdline = { view = "cmdline", conceal = false, icon = "" },
            filter = { view = "cmdline", conceal = false, icon = "" },
            lua = { view = "cmdline", conceal = false, icon = "" },
            help = { view = "cmdline", conceal = false, icon = "" },
          },
        },
      },
    },
  },
}
