-- use magick_cli instead of magick_rock
local use_magick_cli = true

return {
  {
    "3rd/image.nvim",
    lazy = true,
    cond = (vim.g.user_is_wezterm or vim.g.user_is_kitty) and not (use_magick_cli and vim.fn.executable("magick") == 0),
    build = not use_magick_cli,
    opts = {
      processor = use_magick_cli and "magick_cli" or nil,
    },
  },
}
