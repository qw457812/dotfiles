---@class util.path
local M = {}

-- os.getenv("HOME")
M.HOME = vim.uv.os_homedir()

--- Chezmoi source path
M.CHEZMOI = (function()
  local path = M.HOME .. "/.local/share/chezmoi"
  return vim.fn.isdirectory(path) == 1 and path or nil
end)()

M.CONFIG = (function()
  local has_chezmoi = M.CHEZMOI and LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1
  return has_chezmoi and M.CHEZMOI .. "/dot_config/nvim" or vim.fn.stdpath("config") --[[@as string]]
end)()

M.LAZYVIM = require("lazy.core.config").options.root .. "/LazyVim"

--- Replace home directory with '~'
--- https://github.com/echasnovski/mini.files/blob/10ed64157ec45f176decefbdb0e2ba10cccd187f/lua/mini/files.lua#L2365
--- https://github.com/ibhagwan/fzf-lua/blob/769b6636af07ea4587e6c06067d8fe9fb0629390/lua/fzf-lua/path.lua#L253
--- https://github.com/nvim-lualine/lualine.nvim/blob/b431d228b7bbcdaea818bdc3e25b8cdbe861f056/lua/lualine/extensions/nerdtree.lua#L4
---@param path string
---@return string
function M.replace_home_with_tilde(path)
  -- vim.fn.fnamemodify(path, ":~")
  -- require("plenary.path"):new(path):make_relative(M.home)
  return M.HOME and path:gsub("^" .. vim.pesc(M.HOME), "~") or path
end

return M
