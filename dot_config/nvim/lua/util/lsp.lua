---@class util.lsp
local M = {}
local H = {}

---copied from: https://github.com/LazyVim/LazyVim/blob/83468be35062d06896c233d90d2f1c1cd24d84f3/lua/lazyvim/plugins/lsp/keymaps.lua#L44-L62
---@param method string|string[]
function M.has(buffer, method)
  if type(method) == "table" then
    for _, m in ipairs(method) do
      if M.has(buffer, m) then
        return true
      end
    end
    return false
  end
  method = method:find("/") and method or "textDocument/" .. method
  return #vim.lsp.get_clients({ bufnr = buffer, method = method }) > 0
end

--- copied from: https://github.com/neovim/neovim/blob/cf9b36f3d97b6f9c66ffff008bc1b5a5dd14ca98/runtime/lua/vim/lsp/buf.lua#L13-L24
--- @param params? table
--- @return fun(client: vim.lsp.Client): lsp.TextDocumentPositionParams
function M.client_positional_params(params)
  local win = vim.api.nvim_get_current_win()
  return function(client)
    local ret = vim.lsp.util.make_position_params(win, client.offset_encoding)
    if params then
      ret = vim.tbl_extend("force", ret, params)
    end
    return ret
  end
end

---Check if cursor is in range
---copied from: https://github.com/Bekaboo/dropbar.nvim/blob/5439d2f02bb744cecb878aaa23c6c6f8b21a351c/lua/dropbar/sources/lsp.lua#L97-L115
---@param cursor integer[] cursor position (line, character); (1, 0)-based
---@param range lsp.Range 0-based range
---@return boolean
function M.cursor_in_range(cursor, range)
  local cursor0 = { cursor[1] - 1, cursor[2] }
  -- stylua: ignore start
  return (
    cursor0[1] > range.start.line
    or (cursor0[1] == range.start.line
        and cursor0[2] >= range.start.character)
  )
    and (
      cursor0[1] < range['end'].line
      or (cursor0[1] == range['end'].line
          and cursor0[2] <= range['end'].character)
    )
  -- stylua: ignore end
end

function M.pick_definitions()
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").lsp_definitions({ reuse_win = true })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").lsp_definitions({ jump_to_single_result = true, ignore_current_line = true })
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.lsp_definitions()
  end
end

function M.pick_references()
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").lsp_references({ include_declaration = false })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").lsp_references({ jump_to_single_result = true, ignore_current_line = true })
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.lsp_references()
  end
end

--- Go to definition or references if already at definition, like `gd` in vscode and idea but slightly different.
--- https://github.com/neovim/neovim/blob/fb6c059dc55c8d594102937be4dd70f5ff51614a/runtime/lua/vim/lsp/_tagfunc.lua#L25
function M.pick_definitions_or_references()
  vim.lsp.buf_request_all(0, "textDocument/definition", M.client_positional_params(), function(results, ctx)
    if vim.tbl_isempty(results) then
      -- no definitions found, try references
      M.pick_references()
      return
    end

    for _, resp in pairs(results) do
      local err, result = resp.err, resp.result
      if err then
        LazyVim.error(
          string.format("Error executing '%s' (%d): %s", ctx.method, err.code, err.message),
          { title = "LSP" }
        )
      elseif result then
        if result.range then -- Location
          if H.is_same_position(result, ctx.params) then
            -- already at one of the definitions, go to references
            M.pick_references()
            return
          end
        else
          result = result --[[@as (lsp.Location[]|lsp.LocationLink[])]]
          for _, item in pairs(result) do
            if H.is_same_position(item, ctx.params) then
              -- already at one of the definitions, go to references
              M.pick_references()
              return
            end
          end
        end
      end
    end
    -- not at any definition, go to definitions
    M.pick_definitions()
  end)
end

--- Is the result's location the same as the params location?
--- https://github.com/DNLHC/glance.nvim/blob/51059bcf21016387b6233c89eed220cf47fca752/lua/glance/range.lua#L24
--- https://github.com/neovim/neovim/blob/fb6c059dc55c8d594102937be4dd70f5ff51614a/runtime/lua/vim/lsp/_tagfunc.lua#L42
---@param result lsp.Location|lsp.LocationLink
---@param params lsp.TextDocumentPositionParams
---@return boolean
function H.is_same_position(result, params)
  local uri = result.uri or result.targetUri
  local range = result.range or result.targetSelectionRange
  if uri ~= params.textDocument.uri then
    -- not the same file
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

return M
