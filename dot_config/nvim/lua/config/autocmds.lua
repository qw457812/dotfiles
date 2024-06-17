-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
-- https://www.chezmoi.io/user-guide/tools/editor/#use-chezmoi-with-vim
-- https://github.com/xvzc/chezmoi.nvim#treat-all-files-in-chezmoi-source-directory-as-chezmoi-files
-- automatically apply changes on files under chezmoi source path: ~/.local/share/chezmoi/*
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { os.getenv("HOME") .. "/.local/share/chezmoi/*" },
  callback = function()
    vim.schedule(require("chezmoi.commands.__edit").watch)
  end,
})
