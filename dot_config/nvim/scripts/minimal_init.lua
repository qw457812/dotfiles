-- nvim --headless --noplugin -u ~/.local/share/chezmoi/dot_config/nvim/scripts/minimal_init.lua -c "lua MiniTest.run()"
-- nvim --headless --noplugin -u ~/.config/nvim/scripts/minimal_init.lua -c "lua MiniTest.run()"
local init_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(init_path))

vim.opt.runtimepath:append(root)
vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/mini.test")

require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.globpath(root .. "/tests", "**/test_*.lua", true, true)
    end,
  },
})
