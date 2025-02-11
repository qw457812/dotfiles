---@class util.lualine
local M = {}

-- -- https://github.com/Bekaboo/dropbar.nvim/blob/998441a88476af2ec77d8cb1b21bae62c9f548c1/lua/dropbar/utils/bar.lua#L11
-- local function hl_str(str, hl)
--   return "%#" .. hl .. "#" .. str .. "%*"
-- end

local function ft_icon()
  -- require("mini.icons").get("file", vim.fn.expand("%:t"))
  local icon, hl, is_default = require("mini.icons").get("filetype", vim.bo.filetype) --[[@as string, string, boolean]]
  if not is_default then
    return icon .. " ", hl
  end
end

-- https://github.com/aimuzov/LazyVimx/blob/a27d3439b9021d1215ce6471f59d801df32c18d4/lua/lazyvimx/extras/hacks/lazyvim-lualine-pretty-path.lua
local function pretty_path(o)
  return function(self)
    return LazyVim.lualine.pretty_path(o)(self):gsub("/", "󰿟")
  end
end

M.pretty_path = {
  pretty_path({
    relative = "root",
    directory_hl = "Conceal",
  }),
}

M.filename = {
  "filename",
  file_status = true,
  newfile_status = true, -- `nvim new_file`
  symbols = {
    modified = "",
    readonly = " 󰌾 ",
  },
  color = function()
    local fg
    if vim.bo.modified then
      fg = Snacks.util.color("MatchParen")
    elseif vim.bo.modifiable == false then
      fg = Snacks.util.color("DiagnosticError")
    elseif vim.bo.readonly == true then
      fg = Snacks.util.color("MiniIconsPurple")
    end
    return { fg = fg, gui = "bold" }
  end,
  fmt = function(name, context)
    local _, _, class = U.java.parse_jdt_uri(vim.api.nvim_buf_get_name(0))
    return class and ("%s.class %s"):format(class, context.options.symbols.readonly) or name
  end,
}

-- https://github.com/Matt-FTW/dotfiles/blob/b12af2bc28c89c7185c48d6b02fb532b6d8be45d/.config/nvim/lua/plugins/extras/ui/lualine-extended.lua
M.formatter = {
  function()
    return " " -- 󰛖 
  end,
  cond = function()
    local ok, conform = pcall(require, "conform")
    if not ok then
      return false
    end
    local formatters = conform.list_formatters(0)
    if #formatters > 0 then
      return true
    end
    local lsp_format = require("conform.lsp_format")
    local lsp_clients = lsp_format.get_format_clients({ bufnr = vim.api.nvim_get_current_buf() })
    return #lsp_clients > 0
  end,
  color = function()
    return { fg = Snacks.util.color("MiniIconsCyan") } -- Identifier
  end,
}

M.linter = {
  function()
    return "󰁨 " -- 󱉶
  end,
  cond = function()
    if not package.loaded["lint"] then
      return false
    end
    local lint = require("lint")
    -- respect LazyVim extension `condition`
    -- see: https://github.com/LazyVim/LazyVim/blob/1e83b4f843f88678189df81b1c88a400c53abdbc/lua/lazyvim/plugins/linting.lua#L84
    local linters = lint._resolve_linter_by_ft(vim.bo.filetype)
    -- filter out linters that don't exist or don't match the condition
    local ctx = { filename = vim.api.nvim_buf_get_name(0) }
    ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
    linters = vim.tbl_filter(function(name)
      local l = lint.linters[name]
      return l and not (type(l) == "table" and l.condition and not l.condition(ctx))
    end, linters)
    return #linters > 0
  end,
  color = function()
    return { fg = Snacks.util.color("MiniIconsGreen") }
  end,
}

M.lsp = {
  function()
    return ft_icon() or " " -- 
  end,
  cond = function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    clients = vim.tbl_filter(function(client)
      local ignored = { "null-ls", "copilot", "rime_ls", "harper_ls" }
      return not vim.list_contains(ignored, client.name)
    end, clients)
    return #clients > 0
  end,
  color = function()
    return { fg = Snacks.util.color(select(2, ft_icon()) or "Special") } -- Identifier
  end,
}

M.hlsearch = {
  function()
    return "󱩾 " -- 󱎸 󰺯 󰺮
  end,
  cond = function()
    return vim.v.hlsearch == 1
  end,
  color = function()
    return { fg = Snacks.util.color("CurSearch", "bg") }
  end,
}

M.wrap = {
  function()
    return "󰖶 " -- 
  end,
  cond = function()
    return vim.wo.wrap
  end,
  color = function()
    return { fg = Snacks.util.color("MiniIconsYellow") }
  end,
}

return M
