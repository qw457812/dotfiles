---@type ChadrcConfig
local M = {}

-- Path to overriding theme and highlights files
local highlights = require "custom.highlights"

M.ui = {
  theme = "bearded-arc",
  theme_toggle = { "bearded-arc", "one_light" },

  hl_override = highlights.override,
  hl_add = highlights.add,


  -- xyq https://nvchad.com/docs/config/nvchad_ui
  statusline = {
    theme = "default", -- default/vscode/vscode_colored/minimal

    -- default/round/block/arrow (separators work only for "default" statusline theme;
    -- round and block will work for the minimal theme only)
    separator_style = "block",
    -- overriden_modules = nil,
    -- modules arg here is the default table of modules
    overriden_modules = function(modules)
      -- modules[1] = (function()
      --   return "MODE!"
      -- end)()

      -- define the somefunction anywhwere in your custom dir, just call it well!
      -- modules[2] = somefunction()  

      -- adding a module between 2 modules
      -- Use the table.insert functin to insert at specific index
      -- This will insert a new module at index 2 and previous index 2 will become 3 now
      table.insert(
        modules,
        3,
        (function()
          -- return " between fileInfo and git ! "
          -- local is_buffer_changed = vim.api.nvim_buf_get_option(0, 'modified')
          -- "%#TbLineBufOnModified#  " "%#St_file_info# "
          -- https://github.com/NvChad/ui/blob/v2.0/nvchad_types/all_hl_groups.lua
          return vim.bo[0].modified and "%#TbLineBufOnModified# M " or "" -- or 和 and 短路, 类似于 a?b:c
        end)()
      )
    end,
  },

  -- see ~/.config/nvim/lua/core/default_config.lua and https://nvchad.com/docs/config/nvchad_ui
  tabufline = {
    show_numbers = false,
    enabled = true,
    lazyload = true, -- lazyload it when there are 1+ buffers
    -- lazyload = false, -- This helps me quickly identify which files have unsaved changes
    -- overriden_modules = nil,
    overriden_modules = function(modules)
      modules[4] = (function()
        -- return ""
        -- remove the toggle_themeBtn, see https://github.com/NvChad/ui/blob/v2.0/lua/nvchad/tabufline/modules.lua
        local CloseAllBufsBtn = "%@TbCloseAllBufs@%#TbLineCloseAllBufsBtn#" .. " 󰅖 " .. "%X"
        return CloseAllBufsBtn
      end)()

      -- or table.remove(modules, 4)
    end,
  },
}

M.plugins = "custom.plugins"

-- check core.mappings for table structure
M.mappings = require "custom.mappings"

return M
