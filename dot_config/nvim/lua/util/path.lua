---@class util.path
local M = {}

-- os.getenv("HOME")
M.home = (vim.uv or vim.loop).os_homedir()

--- Chezmoi source path
M.chezmoi = (function()
  local path = M.home .. "/.local/share/chezmoi"
  return vim.fn.isdirectory(path) == 1 and path or nil
end)()

M.config = (function()
  local has_chezmoi = M.chezmoi and LazyVim.has_extra("util.chezmoi") and vim.fn.executable("chezmoi") == 1
  return has_chezmoi and M.chezmoi .. "/dot_config/nvim" or vim.fn.stdpath("config") --[[@as string]]
end)()

M.lazyvim = require("lazy.core.config").options.root .. "/LazyVim"

--- Replace home directory with '~'
--- https://github.com/echasnovski/mini.files/blob/10ed64157ec45f176decefbdb0e2ba10cccd187f/lua/mini/files.lua#L2365
--- https://github.com/ibhagwan/fzf-lua/blob/769b6636af07ea4587e6c06067d8fe9fb0629390/lua/fzf-lua/path.lua#L253
---@param path string
---@return string
function M.replace_home_with_tilde(path)
  -- require("plenary.path"):new(path):make_relative(M.home)
  return M.home and path:gsub("^" .. vim.pesc(M.home), "~") or path
end

return M
