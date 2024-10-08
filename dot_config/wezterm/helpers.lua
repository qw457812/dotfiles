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

return M
