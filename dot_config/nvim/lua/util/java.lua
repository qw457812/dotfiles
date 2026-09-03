---@class util.java
local M = {}

--- https://github.com/sykesm/dotfiles/blob/92169d9a6ca596fddc58ce1771d708e92d779dec/.config/nvim/lua/sykesm/plugins/nvim-jdtls.lua#L39
---@return { name: string, path: string }[]|nil
function M.jdt_java_runtimes()
  local java_home_macos = "/usr/libexec/java_home"
  if not (vim.g.user_is_macos and vim.fn.executable(java_home_macos) == 1) then
    return
  end

  ---@param version string
  ---@return string?
  local function java_home(version)
    local res = vim.system({ java_home_macos, "-F", "-v", version }, { text = true }):wait()
    return res.code == 0 and res.stdout:gsub("\n+$", "") or nil
  end

  local runtimes = {}
  for v = 8, 23 do
    local home = java_home(tostring(v)) or (v == 8 and java_home("1.8"))
    if home then
      -- note that the field `name` must be a valid `ExecutionEnvironment`
      -- https://github.com/eclipse-jdtls/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
      table.insert(runtimes, {
        name = "JavaSE-" .. (v == 8 and "1.8" or tostring(v)),
        path = home,
      })
    end
  end
  return #runtimes > 0 and runtimes or nil
end

-- https://github.com/mfussenegger/nvim-jdtls/issues/423#issuecomment-1429184022
-- JDT.LS builds these URIs in JDTUtils.toUri(IClassFile):
-- https://github.com/eclipse-jdtls/eclipse.jdt.ls/blob/08eafe6ff60c7159ef88571d47b6a9ef82fef94e/org.eclipse.jdt.ls.core/src/org/eclipse/jdt/ls/core/internal/JDTUtils.java
---@param uri string jdt://contents/<classpath-entry>/<optional-package>/<source-file>?<encoded-IClassFile-handle>
---@return nil|string jar
---@return nil|string package
---@return nil|string class
function M.parse_jdt_uri(uri)
  if not vim.startswith(uri, "jdt://contents/") then
    return
  end

  local path, query = uri:match("^jdt://contents/([^?#]+)%?([^#]*)")
  if not path then
    return
  end

  local jar, rest = path:match("^([^/]+)/(.+)$")
  if not jar then
    return
  end

  local pkg, filename = rest:match("^([^/]+)/([^/]+)$")
  if not filename then -- the default package is omitted from the URI path
    pkg, filename = "", rest
  end

  query = vim.uri_decode(query)
  local class = query:match("&element=([^&]+)%.class") or query:match(".*%(([^/()&]+)%.class")
  if class then
    return vim.uri_decode(jar), vim.uri_decode(pkg), vim.uri_decode(class)
  end
end

--- Extract the local classpath JAR from an Eclipse JDT handle in the URI query.
---@param uri string
---@return string?
function M.jdt_uri_to_jar_path(uri)
  local query = uri:match("^jdt://contents/[^?]+%?([^#]*)")
  if not query then
    return
  end

  -- Eclipse handle paths use `\/` as a separator; URI encoding turns that
  -- into `%5C/`. A Windows drive, unlike a Unix root, precedes the first one.
  local drive, jar = query:match("([%a]:)%%5[cC]/(.-%.jar)[=%%]")
  if not jar then
    jar = query:match("%%5[cC]/(.-%.jar)[=%%]")
  end
  if not jar then
    return
  end

  jar = jar:gsub("%%5[cC]/", "/")
  return vim.uri_decode((drive or "") .. "/" .. jar)
end

---@param path string
---@return string
function M.path_shorten(path)
  return (path:gsub("src/main/java/", "s/m/j/"):gsub("src/test/java/", "s/t/j/"))
end

return M
