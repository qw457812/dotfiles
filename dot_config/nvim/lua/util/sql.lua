---@class util.sql
local M = {}

-- :echo db#url#encode('my_password')
-- :=vim.fn['db#url#encode']('my_password')
-- :echo db#url#parse('my_url')
-- :echo db#adapter#dispatch("my_url", "interactive")

M.url = {
  mysql = function(user, password, host, port, database)
    -- mysql://[<user>[:<password>]@][<host>[:<port>]]/[database]
    return string.format("mysql://%s:%s@%s:%s/%s", U.url_encode(user), U.url_encode(password), host, port, database)
  end,
}

return M
