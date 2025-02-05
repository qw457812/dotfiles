---@class util.explorer
local M = {}

--- Make hijack-netrw plugins handle `nvim .` and `:e .` correctly (bad alternative: `lazy = false`)
--- https://github.com/AstroNvim/AstroNvim/blob/4fd4781ab0c2d9c876acef1fc5b3f01773c78be6/lua/astronvim/plugins/neo-tree.lua#L23
--- https://github.com/stevearc/oil.nvim/issues/300#issuecomment-1950541064
--- https://github.com/LazyVim/LazyVim/blob/d5a4ced75acadb6ae151c0d2960a531c691c88b9/lua/lazyvim/plugins/editor.lua#L45
---@param hijack_netrw_plugin string
function M.load_on_directory(hijack_netrw_plugin)
  local function load()
    -- require(hijack_netrw_plugin)
    require("lazy").load({ plugins = { hijack_netrw_plugin } })
  end

  local has_dir_arg = false
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, arg in ipairs(vim.fn.argv()) do
    if vim.fn.isdirectory(arg) == 1 then
      has_dir_arg = true
      break
    end
  end

  if has_dir_arg then
    -- for `nvim .`
    load()
  else
    -- for `:e .`
    vim.api.nvim_create_autocmd("BufNew", {
      group = vim.api.nvim_create_augroup("hijack_netrw_on_directory", { clear = true }),
      desc = "Load hijack-netrw plugin with directory",
      callback = function(event)
        -- package.loaded[hijack_netrw_plugin]
        if LazyVim.is_loaded(hijack_netrw_plugin) then
          return true
        end

        -- vim.fn.isdirectory(vim.fn.expand("<afile>")) == 1
        if vim.fn.isdirectory(vim.api.nvim_buf_get_name(event.buf)) == 1 then
          load()
          -- once plugin is loaded, we can delete this autocmd
          return true
        end
      end,
    })
  end
end

--- Search and Replace from Explorer
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
