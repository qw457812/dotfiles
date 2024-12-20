return {
  -- https://github.com/doctorfree/nvim-lazyman/blob/bb4091c962e646c5eb00a50eca4a86a2d43bcb7c/lua/free/plugins/ui.lua#L212
  {
    "m4xshen/smartcolumn.nvim",
    event = { "BufEnter", "TextChanged", "TextChangedI" },
    opts = {
      colorcolumn = { "80", "100" },
      disabled_filetypes = {
        "alpha",
        "dashboard",
        "dap-repl",
        "dapui_scopes",
        "dapui_breakpoints",
        "dapui_stacks",
        "dapui_watches",
        "dap-terminal",
        "dapui_console",
        "help",
        "lazy",
        "markdown",
        "mason",
        "ministarter",
        "neogitstatus",
        "neo-tree",
        "NvimTree",
        "Outline",
        "lir",
        "oil",
        "octo",
        "packer",
        "spectre_panel",
        "startify",
        "startup",
        "text",
        "toggleterm",
        "Trouble",
      },
      scope = "line",
    },
  },
  {
    "lukas-reineke/virt-column.nvim",
    event = "BufEnter",
    opts = {},
  },
}
