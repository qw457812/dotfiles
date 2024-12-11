return {
  {
    "3rd/image.nvim",
    cond = vim.g.user_is_wezterm or vim.g.user_is_kitty,
    lazy = true,
    opts = {},
    -- -- To use magick_cli instead of magick_rock:
    -- cond = (vim.g.user_is_wezterm or vim.g.user_is_kitty) and vim.fn.executable("magick") == 1,
    -- build = false,
    -- opts = { processor = "magick_cli" },
  },
}
