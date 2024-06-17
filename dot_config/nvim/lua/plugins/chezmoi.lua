return {
  -- https://www.chezmoi.io/user-guide/tools/editor/#use-chezmoi-with-vim
  -- also see: `../config/autocmds.lua` and `telescope.lua`
  {
    "xvzc/chezmoi.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("chezmoi").setup({
        edit = {
          -- automatically apply changes on save by `:ChezmoiEdit` and telescope integration
          watch = true,
          force = false,
        },
        notification = {
          on_open = true,
          on_apply = true,
          -- note: `watch = true` above won't work if set `on_watch = true` here
          on_watch = false,
        },
        telescope = {
          select = { "<CR>" },
        },
      })
    end,
  },
}
