-- https://github.com/yazi-rs/plugins/tree/main/full-border.yazi
require("full-border"):setup()
-- https://github.com/yazi-rs/plugins/tree/main/git.yazi
require("git"):setup()
-- https://github.com/dedukun/bookmarks.yazi
require("bookmarks"):setup({
	last_directory = { enable = true, persist = false },
	persist = "all", -- none(default), all, vim
	desc_format = "full", -- full(default), parent
	file_pick_mode = "parent", -- hover(default), parent
	notify = { enable = true },
})

-- TODO:
-- https://github.com/Matt-FTW/dotfiles/blob/main/.config/yazi/init.lua
-- https://github.com/llanosrocas/yaziline.yazi
