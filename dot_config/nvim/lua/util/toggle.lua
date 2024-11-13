local SnacksToggle = require("snacks.toggle")
local SnacksToggleDiag = SnacksToggle.diagnostics()

---@class util.toggle
local M = {}

-- https://github.com/xzbdmw/nvimconfig/blob/0be9805dac4661803e17265b435060956daee757/lua/config/keymaps.lua#L49
M.has_diagnostic_virtual_text = nil ---@type boolean?
M.diagnostic_virtual_text = SnacksToggle.new({
  name = "Diagnostic Virtual Text",
  get = function()
    if M.has_diagnostic_virtual_text == nil then
      return SnacksToggleDiag:get()
    end
    return M.has_diagnostic_virtual_text
  end,
  set = function(state)
    M.has_diagnostic_virtual_text = state
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
    if state and not SnacksToggleDiag:get() then
      SnacksToggleDiag:set(state)
    end
  end,
})

-- toggle diagnostics and it's virtual text
M.diagnostics = SnacksToggle.new({
  name = "Diagnostics",
  get = function()
    return SnacksToggleDiag:get()
  end,
  set = function(state)
    M.diagnostic_virtual_text:set(state)
    if not state then
      SnacksToggleDiag:set(state)
    end
  end,
})

return M
