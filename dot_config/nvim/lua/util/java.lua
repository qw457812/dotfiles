---@class util.java
local M = {}

-- https://github.com/mfussenegger/nvim-jdtls/issues/423#issuecomment-1429184022
-- copied from: https://github.com/mfussenegger/dotfiles/blob/fa827b77f354b0f31a8352a27cfc1d9a4973a31c/vim/dot-config/nvim/lua/me/init.lua#L231
-- local uri = vim.uri_from_bufnr(bufnr)
---@param uri string
---@return nil|string jar
---@return nil|string package
---@return nil|string class
function M.parse_jdt_uri(uri)
  if vim.startswith(uri, "jdt://") then
    return uri:match("contents/([%a%d._-]+)/([%a%d._-]+)/([%a%d$]+).class")
  end
end

---@param path string
---@return string
function M.path_shorten(path)
  return (path:gsub("src/main/java/", "s/m/j/"):gsub("src/test/java/", "s/t/j/"))
end

return M
