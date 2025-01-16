---@type string[]
local extras = {}

-- https://github.com/neovim/neovim/issues/28906
if vim.fn.has("nvim-0.11") == 0 then
  table.insert(extras, "lazyvim.plugins.extras.editor.mini-diff")
end

---@param extra string
return vim.tbl_map(function(extra)
  return { import = extra }
end, extras)
