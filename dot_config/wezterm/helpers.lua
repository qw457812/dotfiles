local M = {}

--- Extends a list-like table with the values of another list-like table.
---
--- NOTE: This mutates dst!
---
---@generic T: table
---@param dst T List which will be modified and appended to
---@param src table List from which values will be inserted
---@param start integer? Start index on src. Defaults to 1
---@param finish integer? Final index on src. Defaults to `#src`
---@return T dst
function M.list_extend(dst, src, start, finish)
  for i = start or 1, finish or #src do
    table.insert(dst, src[i])
  end
  return dst
end

--- Checks if a list-like table (integer keys without gaps) contains `value`.
---
---@param t table Table to check (must be list-like, not validated)
---@param value any Value to compare
---@return boolean `true` if `t` contains `value`
function M.list_contains(t, value)
  --- @cast t table<any,any>

  for _, v in ipairs(t) do
    if v == value then
      return true
    end
  end
  return false
end

return M
