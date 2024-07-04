if vim.fn.executable("tmux") == 0 then
  return {}
end

return {
  -- https://github.com/arturgoms/nvim/blob/045c55460e36e1d4163b426b2ac66bd710721ac5/lua/3thparty/plugins/tmux.lua
  {
    "aserowy/tmux.nvim",
    event = "VeryLazy",
    opts = {
      copy_sync = {
        -- sync all registers
        enable = false,
      },
      -- define keybindings in ../config/keymaps.lua to override LazyVim's default keybindings
      navigation = {
        -- enables default keybindings (C-hjkl) for normal mode
        enable_default_keybindings = false,
      },
      resize = {
        -- enables default keybindings (A-hjkl) for normal mode
        enable_default_keybindings = false,
      },
    },
  },
}
