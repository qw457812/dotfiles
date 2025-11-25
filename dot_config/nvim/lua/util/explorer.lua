---@class util.explorer
local M = {}

-- TODO: refactor: vim.g.user_explorer_visible and is_visible() in neo-tree.lua
---@return boolean, integer?, integer?
function M.is_visible()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.list_contains({ "neo-tree", "snacks_layout_box" }, vim.bo[buf].filetype) then
      return true, buf, win
    end
  end
  return false
end

-- TODO: current file -> U.last_file(false)
-- reveal the current file in root directory
---@param opts? {focus?: boolean}
function M.open(opts)
  opts = opts or {}
  local focus = opts.focus ~= false
  local root = LazyVim.root()
  if LazyVim.has("neo-tree.nvim") then
    local reveal_file = vim.fn.expand("%:p")
    if reveal_file == "" or not vim.uv.fs_stat(reveal_file) then
      reveal_file = vim.fn.getcwd()
    end
    require("neo-tree.command").execute({
      action = focus and "focus" or "show",
      reveal_file = reveal_file, -- using `reveal_file` instead of `reveal` to reveal cwd for an unsaved file
      reveal_force_cwd = true,
      dir = vim.startswith(reveal_file, root) and root or nil, -- `dir = root` works too
    })
  elseif Snacks.config.explorer.enabled then
    Snacks.explorer.open({
      cwd = root,
      on_show = not focus and vim.schedule_wrap(function()
        vim.cmd("wincmd p")
      end) or nil,
    })
  end
end

function M.close()
  if LazyVim.has("neo-tree.nvim") then
    require("neo-tree.command").execute({ action = "close" })
  elseif Snacks.config.explorer.enabled then
    local picker = Snacks.picker.get({ source = "explorer" })[1]
    if picker then
      picker:close()
    end
  end
end

---@return boolean
function M.has_dir_arg()
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, arg in ipairs(vim.fn.argv()) do
    if vim.fn.isdirectory(arg) == 1 then
      return true
    end
  end
  return false
end

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

  if M.has_dir_arg() then
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
  if grug.has_instance(instance) then
    grug.get_instance(instance):open()
    -- updating the prefills without clearing the search and other fields
    grug.get_instance(instance):update_input_values(prefills, false)
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
