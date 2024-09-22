---@class util.explorer
local M = {}

--- Search and Replace from Explorer
--- https://github.com/MagicDuck/grug-far.nvim#add-minifiles-integration-to-open-search-limited-to-focused-directory
---@param path string
function M.grug_far(path)
  local grug = require("grug-far")

  local prefills = { paths = path }
  local instance = "explorer"
  -- instance check
  if grug.has_instance(instance) then
    grug.open_instance(instance)
    -- updating the prefills without clearing the search and other fields
    grug.update_instance_prefills(instance, prefills, false)
  else
    grug.open({
      instanceName = instance,
      prefills = prefills,
      transient = true,
      staticTitle = "Search and Replace from Explorer",
    })
  end
end

return M
