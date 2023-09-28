-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

-- https://www.lunarvim.org/docs/faq#where-can-i-find-some-example-configs
-- vim.opt.showmode = true
-- vim.opt.relativenumber = true
-- vim.opt.wrap = true -- wrap lines

lvim.colorscheme = "tokyonight"
-- lvim.colorscheme = "github_dark_dimmed"
-- lvim.colorscheme = "onedarker"
-- lvim.colorscheme = "onedark"

-- https://github.com/LunarVim/starter.lvim/blob/java-ide/config.lua
vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "jdtls" })

require("user.keybindings").config()
require("user.plugins").config()

-- Debugging
if lvim.builtin.dap.active then
  require("user.dap").config()
end
