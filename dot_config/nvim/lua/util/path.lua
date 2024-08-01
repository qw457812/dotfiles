local Path = require("plenary.path")

local M = {}

--- replace home directory with `~`
--- https://github.com/ibhagwan/fzf-lua/blob/769b6636af07ea4587e6c06067d8fe9fb0629390/lua/fzf-lua/path.lua#L253
---@param path string?
---@return string?
function M.replace_home_with_tilde(path)
  if not path then
    return nil
  end
  -- vim.env.HOME
  -- os.getenv("HOME")
  local home = vim.uv.os_homedir()
  if not home then
    return path
  end

  -- path = path:gsub("^" .. home, "~") -- lua_regex_escape
  if path == home then
    path = "~"
  elseif vim.startswith(path, home) then
    path = "~/" .. Path:new(path):make_relative(home)
  end
  return path
end

return M
