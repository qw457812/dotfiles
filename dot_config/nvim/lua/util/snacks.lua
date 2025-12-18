---@class util.snacks
local M = {}

M.win = {
  ---copied from: https://github.com/folke/snacks.nvim/blob/3ae98636aaaf8f1b2f55b264f5745ae268de532f/lua/snacks/layout.lua#L247-L258
  ---see also: https://github.com/folke/snacks.nvim/blob/3ae98636aaaf8f1b2f55b264f5745ae268de532f/lua/snacks/layout.lua#L475-L478
  ---@module "snacks"
  ---@param self snacks.win
  fullscreen_height = function(self)
    local bottom = (vim.o.cmdheight + (vim.o.laststatus == 3 and 1 or 0)) or 0
    local top = (vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)) and 1 or 0
    local border = self:border_size()
    return vim.o.lines - top - bottom - border.top - border.bottom
  end,
}

M.picker = {
  ---In favor of U.keymap.clear_ui_esc().
  ---@type fun(picker:snacks.Picker)
  on_show = function()
    vim.cmd("noh")
    vim.g.user_suppress_lsp_progress = true
    if package.loaded["noice"] then
      require("noice").cmd("dismiss")
    end
  end,
  ---@type fun(picker:snacks.Picker)
  on_close = function()
    vim.g.user_suppress_lsp_progress = nil
  end,
  ---Focus the item with the given path when the picker is ready.
  ---@param picker snacks.Picker
  ---@param path string
  follow_file = function(picker, path)
    picker.matcher.task:on(
      "done",
      vim.schedule_wrap(function()
        -- ref: https://github.com/folke/snacks.nvim/blob/ca0f8b2c09a6b437479e7d12bdb209731d9eb621/lua/snacks/picker/config/sources.lua#L236-L242
        for i, item in ipairs(picker:items()) do
          if Snacks.picker.util.path(item) == path then
            picker.list:view(i)
            Snacks.picker.actions.list_scroll_center(picker)
            break
          end
        end
      end)
    )
  end,
  -- copied from: https://github.com/folke/snacks.nvim/blob/27cba535a6763cbca3f3162c5c4bb48c6f382005/lua/snacks/picker/config/layouts.lua
  ---@type table<string, snacks.picker.layout.Config>
  layouts = {
    based_telescope = {
      layout = {
        box = "horizontal",
        backdrop = false,
        width = 0.8,
        height = 0.8,
        border = "none",
        {
          box = "vertical",
          {
            win = "input",
            height = 1,
            border = "rounded",
            title = "{title} {live} {flags}",
            title_pos = "center",
          },
          { win = "list", title = " Results ", title_pos = "center", border = "rounded" },
        },
        {
          win = "preview",
          title = "{preview:Preview}",
          width = 0.5,
          border = "rounded",
          title_pos = "center",
        },
      },
    },
    -- based on the dropdown preset, mainly for termux
    narrow = {
      layout = {
        backdrop = false,
        width = 0.5,
        min_width = 80,
        height = 0.8,
        min_height = math.min(35, vim.o.lines - 1), -- 1 for lualine.nvim
        border = "none",
        box = "vertical",
        { win = "preview", title = "{preview}", height = 0.45, border = "rounded" },
        {
          box = "vertical",
          border = "rounded",
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
      },
    },
    -- based on the default preset
    -- see also: https://github.com/folke/snacks.nvim/blob/fa29c6c92631026a7ee41249c78bd91562e67a09/lua/snacks/win.lua#L186-L191
    borderless = {
      layout = {
        box = "horizontal",
        width = 0.8,
        min_width = 120,
        height = 0.8,
        border = "none",
        {
          box = "vertical",
          border = "solid",
          title = "{title} {live} {flags}",
          { win = "input", height = 1, border = { "", "", "", "", "", " ", "", "" } },
          { win = "list", border = "none" },
        },
        { win = "preview", title = "{preview}", border = "solid", width = 0.5 },
      },
    },
    -- based on the narrow layout
    borderless_narrow = {
      layout = {
        backdrop = false,
        width = 0.5,
        min_width = 80,
        height = 0.8,
        min_height = math.min(35, vim.o.lines - 1),
        border = "none",
        box = "vertical",
        { win = "preview", title = "{preview}", height = 0.45, border = "solid" },
        {
          box = "vertical",
          border = "solid",
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = { "", "", "", "", "", " ", "", "" } },
          { win = "list", border = "none" },
        },
      },
    },
    -- add a few borders to split input, list and preview
    based_borderless = {
      layout = {
        box = "horizontal",
        width = 0.8,
        min_width = 120,
        height = 0.8,
        border = "none",
        {
          box = "vertical",
          border = "solid",
          title = "{title} {live} {flags}",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
        {
          win = "preview",
          title = "{preview}",
          border = { " ", " ", " ", " ", " ", " ", " ", "│" },
          width = 0.5,
        },
      },
    },
    based_borderless_narrow = {
      layout = {
        backdrop = false,
        width = 0.5,
        min_width = 80,
        height = 0.8,
        min_height = math.min(35, vim.o.lines - 1),
        border = "none",
        box = "vertical",
        { win = "preview", title = "{preview}", height = 0.45, border = "solid" },
        {
          box = "vertical",
          border = { " ", "─", " ", " ", " ", " ", " ", " " },
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
      },
    },
    -- git
    -- based on the narrow preset, with fullscreen and bigger preview
    diff = {
      layout = {
        backdrop = false,
        width = 0,
        height = M.win.fullscreen_height,
        border = "none",
        box = "vertical",
        { win = "preview", title = "{preview}", height = 0.75, border = "rounded" },
        {
          box = "vertical",
          border = "rounded",
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
      },
    },
    borderless_diff = {
      layout = {
        backdrop = false,
        width = 0,
        height = M.win.fullscreen_height,
        border = "none",
        box = "vertical",
        { win = "preview", title = "{preview}", height = 0.75, border = "solid" },
        {
          box = "vertical",
          border = "solid",
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = { "", "", "", "", "", " ", "", "" } },
          { win = "list", border = "none" },
        },
      },
    },
    based_borderless_diff = {
      layout = {
        backdrop = false,
        width = 0,
        height = M.win.fullscreen_height,
        border = "none",
        box = "vertical",
        { win = "preview", title = "{preview}", height = 0.75, border = "solid" },
        {
          box = "vertical",
          border = { " ", "─", " ", " ", " ", " ", " ", " " },
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
      },
    },
  },
}

return M
