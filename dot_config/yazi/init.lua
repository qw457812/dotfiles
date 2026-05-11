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
-- TODO: remove th.git fallback once Termux ships yazi >= 26.5.6
--  https://repology.org/project/yazi/versions (Termux: 26.1.22)
--  git signs are now configured in theme.toml [git] section (yazi-rs/plugins@1db18bb)
---@diagnostic disable-next-line: inject-field
th.git = th.git or {}
if not th.git.ignored_sign then
  -- ya.notify({ title = "git", content = "using init.lua fallback", timeout = 3 })
  th.git.ignored_sign = "I"
  th.git.untracked_sign = "?"
  th.git.modified_sign = "M"
  th.git.added_sign = "A"
  th.git.deleted_sign = "D"
  th.git.updated_sign = "U"
else
  -- ya.notify({ title = "git", content = "using theme.toml [git] section", timeout = 3 })
end
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
  show_keys = true,
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
