local function pick_definitions()
  if LazyVim.pick.want() == "telescope" then
    require("telescope.builtin").lsp_definitions({ reuse_win = true })
  elseif LazyVim.pick.want() == "fzf" then
    require("fzf-lua").lsp_definitions({ jump_to_single_result = true, ignore_current_line = true })
  end
end

local function pick_references()
  if LazyVim.pick.want() == "telescope" then
    require("telescope.builtin").lsp_references({ include_declaration = false })
  elseif LazyVim.pick.want() == "fzf" then
    require("fzf-lua").lsp_references({ jump_to_single_result = true, ignore_current_line = true })
  end
end

--- Is the result's location the same as the params location?
--- https://github.com/mrcjkb/haskell-tools.nvim/blob/6b6fa211da47582950abfab9e893ab936b6c4298/lua/haskell-tools/lsp/hover.lua#L105
--- https://github.com/DNLHC/glance.nvim/blob/51059bcf21016387b6233c89eed220cf47fca752/lua/glance/range.lua#L24
---@param result table LSP result
---@param params table LSP location params
---@return boolean
local function is_same_position(result, params)
  local uri = result.uri or result.targetUri
  if uri ~= params.textDocument.uri then
    -- not the same file
    return false
  end
  local range = result.targetRange or result.range or result.targetSelectionRange
  if not (range and range.start and range["end"]) then
    return false
  end
  if params.position.line < range.start.line or params.position.line > range["end"].line then
    return false
  end
  if params.position.line == range.start.line and params.position.character < range.start.character then
    return false
  end
  if params.position.line == range["end"].line and params.position.character > range["end"].character then
    return false
  end
  return true
end

--- Go to definition or references if already at definition, like `gd` in vscode and idea but slightly different.
--- https://github.com/ray-x/navigator.lua/blob/db3ac40bd4793abf90372687e35ece1c8969acc9/lua/navigator/definition.lua#L62
--- https://github.com/mrcjkb/haskell-tools.nvim/blob/6b6fa211da47582950abfab9e893ab936b6c4298/lua/haskell-tools/lsp/hover.lua#L188
--- https://github.com/fcying/dotvim/blob/47c7f8faa600e1045cc4ac856d639f5f23f00cf4/lua/util.lua#L146
--- https://github.com/mbriggs/nvim-v2/blob/d8526496596f3a4dcab2cde86674ca58eaee65e2/lsp_fixcurrent.lua
local function pick_definitions_or_references()
  local params = vim.lsp.util.make_position_params()
  local results = vim.lsp.buf_request_sync(0, "textDocument/definition", params)
  if not results or vim.tbl_isempty(results) then
    -- no definitions found, try references
    pick_references()
  else
    for _, result in pairs(results) do
      if result.result then
        for _, definition_result in pairs(result.result) do
          if is_same_position(definition_result, params) then
            -- already at one of the definitions, go to references
            pick_references()
            return
          end
        end
      end
    end
    -- not at any definition, go to definitions
    pick_definitions()
  end
end

return {
  -- LSP Keymaps
  -- https://www.lazyvim.org/plugins/lsp#%EF%B8%8F-customizing-lsp-keymaps
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/telescope.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/fzf.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/lsp/keymaps.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/inc-rename.lua
  {
    "neovim/nvim-lspconfig",
    opts = function()
      local Keys = require("lazyvim.plugins.lsp.keymaps").get()
      vim.list_extend(Keys, {
        -- { "gd", pick_lsp_definitions_or_references, desc = "Goto Definition/References", has = "definition" },
        { "<cr>", pick_definitions_or_references, desc = "Goto Definition/References", has = "definition" },
      })
    end,
  },
}
