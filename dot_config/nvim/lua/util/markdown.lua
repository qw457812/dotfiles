---@class util.markdown
local M = {}

---@param filetype string
function M.render_markdown_ft(filetype)
  local plugin = LazyVim.get_plugin("render-markdown.nvim")
  -- :=require("render-markdown").default_config.file_types
  -- local ft = plugin and require("lazy.core.plugin").values(plugin, "ft", false) or { "markdown" }
  local ft = plugin and plugin.ft or { "markdown" }
  ft = type(ft) == "table" and ft or { ft }
  ft = vim.deepcopy(ft)
  table.insert(ft, filetype)
  return ft
end

return M
