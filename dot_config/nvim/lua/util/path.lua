local Path = require("plenary.path")

local M = {}

--- replace home directory with `~`
---@param path string
function M.replace_home_with_tilde(path)
  -- vim.env.HOME
  -- os.getenv("HOME")
  local home = vim.loop.os_homedir()
  if home and vim.startswith(path, home) then
    -- path = path:gsub(home, "~")
    path = "~/" .. Path:new(path):make_relative(home)
  end
  return path
end

return M
