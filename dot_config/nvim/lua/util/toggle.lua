local st = require("snacks.toggle")
local st_diag = st.diagnostics()

---@class util.toggle
local M = {}

-- https://github.com/xzbdmw/nvimconfig/blob/0be9805dac4661803e17265b435060956daee757/lua/config/keymaps.lua#L49
M.is_diagnostic_virt_enabled = nil ---@type boolean?
M.diagnostic_virt = st({
  name = "Diagnostic Virtual Text",
  get = function()
    if M.is_diagnostic_virt_enabled == nil then
      return st_diag:get()
    end
    return M.is_diagnostic_virt_enabled
  end,
  set = function(state)
    M.is_diagnostic_virt_enabled = state
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
    if state and not st_diag:get() then
      st_diag:set(state)
    end
  end,
})

-- toggle diagnostics and it's virtual text
M.diagnostics = st({
  name = "Diagnostics",
  get = function()
    return st_diag:get()
  end,
  set = function(state)
    M.diagnostic_virt:set(state)
    if not state then
      st_diag:set(state)
    end
  end,
})

---@type table<string, snacks.toggle.Class>
M.ai_cmps = {}
M.ai_cmp = st({
  name = "AI Completion",
  get = function()
    return vim.tbl_count(vim.tbl_filter(function(ai)
      return ai:get()
    end, M.ai_cmps)) > 0
  end,
  set = function(state)
    for _, ai in pairs(M.ai_cmps) do
      ai:set(state)
    end
  end,
})

if vim.g.neovide then
  -- https://github.com/folke/zen-mode.nvim/blob/29b292bdc58b76a6c8f294c961a8bf92c5a6ebd6/lua/zen-mode/config.lua#L70
  -- https://neovide.dev/faq.html#how-to-turn-off-all-animations
  local disable_animations = {
    neovide_animation_length = 0,
    neovide_cursor_animate_command_line = false,
    neovide_scroll_animation_length = 0,
    neovide_position_animation_length = 0,
    neovide_cursor_animation_length = 0,
    neovide_cursor_vfx_mode = "",
    neovide_cursor_trail_size = 0,
    neovide_cursor_animate_in_insert_mode = false,
    neovide_scroll_animation_far_lines = 0,
  }
  local cache_animations = {} ---@type table<string, any>
  M.neovide_animations = st({
    name = "Neovide Animate",
    get = function()
      return vim.g.neovide_cursor_animate_command_line
    end,
    set = function(state)
      -- https://github.com/folke/zen-mode.nvim/blob/29b292bdc58b76a6c8f294c961a8bf92c5a6ebd6/lua/zen-mode/plugins.lua#L130
      if state then
        for key, _ in pairs(disable_animations) do
          vim.g[key] = cache_animations[key]
        end
      else
        for key, value in pairs(disable_animations) do
          cache_animations[key] = vim.g[key]
          vim.g[key] = value
        end
      end
    end,
  })
end

return M
