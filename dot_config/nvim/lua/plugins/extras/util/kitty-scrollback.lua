---@module "lazy"
---@type LazySpec
return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    cond = vim.g.terminal_scrollback_pager == true, -- disable for pager/manpager
    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
      "KittyScrollbackGenerateCommandLineEditing",
    },
    event = "User KittyScrollbackLaunch",
    opts = {},
  },
}
