LazyVimToggle = LazyVim.toggle

---@class util.toggle
---@field wrap fun(toggle:lazyvim.Toggle):lazyvim.Toggle.wrap
---@field wk fun(lhs:string, toggle:lazyvim.Toggle)
local M = {}

setmetatable(M, {
  __index = function(_, k)
    if LazyVimToggle[k] then
      return LazyVimToggle[k]
    end
  end,
  __call = function(_, ...)
    return LazyVimToggle(...)
  end,
})

---@param lhs string
---@param toggle lazyvim.Toggle
function M.map(lhs, toggle)
  local t = M.wrap(toggle)
  U.keymap("n", lhs, function()
    t()
  end, { desc = "Toggle " .. toggle.name })
  M.wk(lhs, toggle)
end

-- https://github.com/xzbdmw/nvimconfig/blob/0be9805dac4661803e17265b435060956daee757/lua/config/keymaps.lua#L49
local has_diagnostic_virtual_text = nil
M.diagnostic_virtual_text = M.wrap({
  name = "Diagnostic Virtual Text",
  get = function()
    if has_diagnostic_virtual_text == nil then
      return LazyVimToggle.diagnostics.get()
    end
    return has_diagnostic_virtual_text
  end,
  set = function(state)
    has_diagnostic_virtual_text = state
    if LazyVim.has("tiny-inline-diagnostic.nvim") then
      if state then
        require("tiny-inline-diagnostic").enable()
      else
        require("tiny-inline-diagnostic").disable()
      end
    else
      -- https://github.com/LazyVim/LazyVim/blob/3dbace941ee935c89c73fd774267043d12f57fe2/lua/lazyvim/plugins/lsp/init.lua#L18
      vim.diagnostic.config({
        virtual_text = state and {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        } or false,
      })
    end
    if state and not LazyVimToggle.diagnostics.get() then
      LazyVimToggle.diagnostics.set(state)
    end
  end,
})

-- toggle diagnostics and it's virtual text
M.diagnostics = M.wrap({
  name = "Diagnostics",
  get = LazyVimToggle.diagnostics.get,
  set = function(state)
    M.diagnostic_virtual_text.set(state)
    if not state then
      LazyVimToggle.diagnostics.set(state)
    end
  end,
})

return M
