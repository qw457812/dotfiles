---@class util.java
local M = {}

--- https://github.com/sykesm/dotfiles/blob/92169d9a6ca596fddc58ce1771d708e92d779dec/.config/nvim/lua/sykesm/plugins/nvim-jdtls.lua#L39
---@return { name: string, path: string }|nil
function M.jdt_java_runtimes()
  local java_home_macos = "/usr/libexec/java_home"
  if vim.fn.has("macunix") == 0 or vim.fn.executable(java_home_macos) == 0 then
    return
  end

  local function java_home(version)
    local res = vim.system({ java_home_macos, "-F", "-v", version }, { text = true }):wait()
    return res.code == 0 and res.stdout:gsub("[\r\n]+$", "")
  end

  local runtimes = {}
  for i = 8, 23 do
    local version = tostring(i)
    local home = java_home(version)
    if not home and version == "8" then
      home = java_home("1.8")
    end
    if home then
      -- note that the field `name` must be a valid `ExecutionEnvironment`
      -- https://github.com/eclipse-jdtls/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
      table.insert(runtimes, {
        name = "JavaSE-" .. (version == "8" and "1.8" or version),
        path = home,
      })
    end
  end
  return not vim.tbl_isempty(runtimes) and runtimes or nil
end

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
