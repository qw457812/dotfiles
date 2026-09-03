-- cd ~/.config/nvim && nvim --headless --noplugin -u scripts/minimal_init.lua -c "lua MiniTest.run()"
vim.opt.runtimepath:append(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/mini.test")

require("mini.test").setup()
