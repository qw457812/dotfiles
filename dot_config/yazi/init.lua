-- https://github.com/yazi-rs/plugins/tree/main/smart-enter.yazi
require("smart-enter"):setup({
  open_multi = true,
})
require("zoxide"):setup({
  update_db = true,
})
-- https://yazi-rs.github.io/docs/dds/#session.lua
require("session"):setup({
  sync_yanked = true,
})
-- https://yazi-rs.github.io/docs/tips/#folder-rules
require("folder-rules"):setup()
-- https://github.com/yazi-rs/plugins/tree/main/full-border.yazi
require("full-border"):setup()
-- https://github.com/yazi-rs/plugins/tree/main/git.yazi
require("git"):setup()
-- -- https://github.com/llanosrocas/githead.yazi
-- require("githead"):setup({
--   -- powerlevel10k style
--   branch_prefix = "",
--   branch_color = "#54d100",
--   branch_symbol = "",
--   branch_borders = "",
-- })
-- https://github.com/Rolv-Apneseth/starship.yazi
require("starship"):setup()
-- https://github.com/dedukun/bookmarks.yazi
require("bookmarks"):setup({
  last_directory = { enable = true, persist = false },
  persist = "all", -- none(default), all, vim
  desc_format = "full", -- full(default), parent
  file_pick_mode = "parent", -- hover(default), parent
  notify = { enable = true },
})

-- TODO:
-- https://github.com/hankertrix/augment-command.yazi
-- https://github.com/Matt-FTW/dotfiles/blob/main/.config/yazi/init.lua
-- https://github.com/imsi32/yatline.yazi
-- https://github.com/imsi32/yatline-githead.yazi
-- https://github.com/yazi-rs/plugins/tree/main/mactag.yazi
-- https://github.com/sxyazi/yazi/issues/51
-- https://github.com/AnirudhG07/awesome-yazi
