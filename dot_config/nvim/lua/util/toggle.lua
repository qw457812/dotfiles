local st = require("snacks.toggle")
local st_diag = st.diagnostics()
local st_zen = assert(st.get("zen"))

---@class util.toggle
local M = {}

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
      M._diag_conf = M._diag_conf or vim.diagnostic.config()
      vim.diagnostic.config({ virtual_text = state and M._diag_conf.virtual_text or false })
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

M.explorer_auto_close = st({
  name = "Explorer Auto Close",
  get = function()
    return vim.g.user_explorer_auto_close
  end,
  set = function(state)
    vim.g.user_explorer_auto_close = state
    if state then
      U.explorer.close()
    else
      U.explorer.open({ focus = false })
    end
  end,
})

M.explorer_auto_open = st({
  name = "Explorer Auto Open",
  get = function()
    return vim.g.user_explorer_auto_open
  end,
  set = function(state)
    vim.g.user_explorer_auto_open = state
    if vim.g.user_explorer_auto_close then
      vim.schedule(function()
        LazyVim.warn(
          "`Explorer Auto Close` is enabled, `Explorer Auto Open` will not work.",
          { title = "Explorer Auto Open" }
        )
      end)
      return
    end
    if state then
      if vim.api.nvim_win_get_width(0) - vim.g.user_explorer_width >= 120 then
        U.explorer.open({ focus = false })
      end
    else
      U.explorer.close()
    end
  end,
})

M.zen = st({
  name = "Zen Mode",
  get = function()
    return st_zen:get() or (package.loaded["zen-mode"] and require("zen-mode.view").is_open())
  end,
  set = function(state)
    if state then
      local function open()
        -- close or unfocus neo-tree first
        if vim.bo.filetype == "neo-tree" then
          if vim.g.user_explorer_auto_close then
            require("neo-tree.command").execute({ action = "close" })
          else
            vim.cmd("wincmd p")
          end
        end
        if LazyVim.has("zen-mode.nvim") then
          require("zen-mode").open()
        else
          st_zen:set(true)
        end
      end
      if vim.fn.getcmdwintype() ~= "" then
        vim.cmd("q")
        vim.schedule(open)
      else
        open()
      end
    else
      if st_zen:get() then
        st_zen:set(false)
      elseif package.loaded["zen-mode"] and require("zen-mode.view").is_open() then
        require("zen-mode").close()
      end
    end
  end,
})

---@type table<string, snacks.toggle.Class>
M.ai_cmps = {}
M.ai_cmp = st({
  name = "AI Completion",
  get = function()
    return not vim.tbl_isempty(vim.tbl_filter(function(ai)
      return ai:get()
    end, M.ai_cmps))
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
