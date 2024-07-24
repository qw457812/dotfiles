return {
  -- https://github.com/arturgoms/nvim/blob/045c55460e36e1d4163b426b2ac66bd710721ac5/lua/3thparty/plugins/tmux.lua
  {
    "aserowy/tmux.nvim",
    event = "VeryLazy",
    cond = function()
      return vim.env.TMUX ~= nil
    end,
    opts = {
      -- to work with yanky.nvim, see: https://github.com/moetayuko/nvimrc/blob/ae242cc18559cd386c36feb9f999b1a9596c7d09/lua/plugins/tmux.lua
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
