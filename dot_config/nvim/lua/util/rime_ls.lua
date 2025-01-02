---@class util.rime_ls
local M = {}

-- copied from: https://github.com/Kaiser-Yang/dotfiles/blob/bdda941b06cce5c7505bc725f09dd3fa17763730/.config/nvim/lua/plugins/rime_ls.lua

local function contains_unacceptable_character(content)
  if content == nil then
    return true
  end
  local ignored_head_number = false
  for i = 1, #content do
    local b = string.byte(content, i)
    if b >= 48 and b <= 57 or b == 32 or b == 46 then
      -- number dot and space
      if ignored_head_number then
        return true
      end
    elseif b <= 127 then
      return true
    else
      ignored_head_number = true
    end
  end
  return false
end

M.lualine = {
  function()
    return "ㄓ"
  end,
  cond = function()
    return vim.g.rime_enabled
  end,
  color = function()
    return { fg = Snacks.util.color("MiniIconsRed") }
  end,
}

---@param item blink.cmp.CompletionItem
function M.is_rime_item(item)
  if item == nil or item.source_name ~= "LSP" then
    return false
  end
  local client = vim.lsp.get_client_by_id(item.client_id)
  return client ~= nil and client.name == "rime_ls"
end

function M.rime_item_acceptable(item)
  return not contains_unacceptable_character(item.label)
end

function M.get_n_rime_item_index(n, items)
  if items == nil then
    items = require("blink.cmp.completion.list").items
  end
  local result = {}
  if items == nil or #items == 0 then
    return result
  end
  for i, item in ipairs(items) do
    if M.is_rime_item(item) and M.rime_item_acceptable(item) then
      result[#result + 1] = i
      if #result == n then
        break
      end
    end
  end
  return result
end

--- @class RimeSetupOpts
--- @field filetype string|string[]

--- @param opts RimeSetupOpts
function M.setup(opts)
  local configs = require("lspconfig.configs")
  vim.g.rime_enabled = false
  configs.rime_ls = {
    default_config = {
      name = "rime_ls",
      cmd = { "rime_ls" },
      filetypes = opts and opts.filetype or { "*" },
      single_file_support = true,
    },
    settings = {},
  }
end

return M
