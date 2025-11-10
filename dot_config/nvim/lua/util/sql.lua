---@class util.sql
local M = {}

---@class user.util.sql.url.Opts
---@field user string
---@field password string
---@field host? string
---@field port? string
---@field database? string

---@class user.util.sql.Db: user.util.sql.url.Opts
---@field name string

---@alias user.util.sql.Db.type "postgresql"|"mysql"|"oracle"

---@type table<user.util.sql.Db.type, string>
local default_ports = {
  postgresql = "5432",
  mysql = "3306",
  oracle = "1521",
}

---@param type user.util.sql.Db.type
---@param opts user.util.sql.url.Opts
---@return string?
local function build_url(type, opts)
  local default_port = default_ports[type]
  if not default_port then
    return
  end

  -- :echo db#url#encode('my_password')
  -- :=vim.fn['db#url#encode']('my_password')
  -- :echo db#url#parse('my_url')
  -- :echo db#adapter#dispatch("my_url", "interactive")
  return string.format(
    "%s://%s:%s@%s:%s/%s",
    type,
    U.url_encode(opts.user),
    U.url_encode(opts.password),
    opts.host or "localhost",
    opts.port or default_port,
    opts.database or ""
  )
end

---@param dbs_by_type table<user.util.sql.Db.type, user.util.sql.Db[]>
function M.add_dbs_to_dadbod_ui(dbs_by_type)
  local all_dbs = {}
  for type, dbs in pairs(dbs_by_type) do
    for _, db in ipairs(dbs) do
      local url = build_url(type, db)
      if url then
        table.insert(all_dbs, { name = db.name, url = url })
      end
    end
  end
  vim.g.dbs = vim.list_extend(vim.g.dbs or {}, all_dbs)
end

return M
