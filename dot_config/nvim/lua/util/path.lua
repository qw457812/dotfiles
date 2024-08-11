local M = {}

--- Replace home directory with '~'
--- https://github.com/echasnovski/mini.files/blob/10ed64157ec45f176decefbdb0e2ba10cccd187f/lua/mini/files.lua#L2365
--- https://github.com/ibhagwan/fzf-lua/blob/769b6636af07ea4587e6c06067d8fe9fb0629390/lua/fzf-lua/path.lua#L253
---@param path string?
---@return string?
function M.replace_home_with_tilde(path)
  if not path then
    return nil
  end

  -- vim.env.HOME
  -- os.getenv("HOME")
  local home = (vim.uv or vim.loop).os_homedir()
  if not home then
    return path
  end

  -- if vim.startswith(path, home) then
  --   local p = require("plenary.path"):new(path):make_relative(home)
  --   path = p == "." and "~" or "~/" .. p
  -- end
  path = path:gsub("^" .. vim.pesc(home), "~")
  return path
end

return M
