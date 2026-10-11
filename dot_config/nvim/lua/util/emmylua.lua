local M = {}

---@param client vim.lsp.Client
function M.attach(client)
  local Lsp = require("lazydev.lsp")
  local Workspace = require("lazydev.workspace")
  -- Attach once so lazydev's later LspAttach callback won't replace this handler.
  -- https://github.com/folke/lazydev.nvim/blob/ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d/lua/lazydev/lsp.lua#L19-L26
  Lsp.attach(client)
  local handler = client.handlers["workspace/configuration"]

  client.handlers["workspace/configuration"] = function(err, params, ctx, config)
    local response = handler(err, params, ctx, config)
    for i, item in ipairs(params.items or {}) do
      if item.section == "emmylua" then
        local ws = item.scopeUri and Workspace.get(client, vim.uri_to_fname(item.scopeUri)) or Workspace.single(client)
        if ws:enabled() then
          ws:update()
          -- https://github.com/folke/lazydev.nvim/blob/ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d/lua/lazydev/workspace.lua#L188-L201
          local lua = ws.settings.Lua or {}
          local workspace_library = (vim.uv.fs_realpath(ws.root) or ws.root) .. "/lua"
          local libraries = lua.workspace and lua.workspace.library or {}
          local require_pattern = vim.deepcopy(lua.runtime and lua.runtime.path or {})
          -- Analyze project assignments after library type declarations.
          -- Keeping lua/ in the workspace avoids library-order-dependent definition lookup.
          -- E.g. vim.g.user_is_termux must bind after LazyVimGlobals replaces the vim.g type.
          -- https://github.com/EmmyLuaLs/emmylua-analyzer-rust/blob/6f8b4246634aa24c140bd7abb78f0a3083d67e73/crates/emmylua_code_analysis/src/compilation/analyzer/mod.rs#L128-L142
          if vim.tbl_contains(libraries, workspace_library) then
            local patterns = {}
            for _, pattern in ipairs(require_pattern) do
              patterns[#patterns + 1] = "lua/" .. pattern
            end
            vim.list_extend(patterns, require_pattern)
            require_pattern = patterns
          end
          local settings = vim.deepcopy((client.settings.emmylua or {}) --[[@as table<string, any>]])
          -- EmmyLua prefers this section over Lua, so include lazydev's dynamic settings here.
          -- https://github.com/EmmyLuaLs/emmylua-analyzer-rust/blob/6f8b4246634aa24c140bd7abb78f0a3083d67e73/crates/emmylua_ls/src/handlers/initialized/client_config/mod.rs#L36-L37
          -- https://github.com/EmmyLuaLs/emmylua-analyzer-rust/blob/6f8b4246634aa24c140bd7abb78f0a3083d67e73/crates/emmylua_ls/src/handlers/initialized/client_config/default_config.rs#L28-L56
          settings.runtime = vim.tbl_extend("keep", settings.runtime or {}, {
            version = lua.runtime and lua.runtime.version,
            requirePattern = require_pattern,
          })
          settings.workspace = settings.workspace or {}
          local library = settings.workspace.library or {}
          for _, path in ipairs(libraries) do
            if path ~= workspace_library and not vim.tbl_contains(library, path) then
              library[#library + 1] = path
            end
          end
          settings.workspace.library = library
          response[i] = settings
        end
      end
    end
    return response
  end

  local refresh = client.handlers["workspace/diagnostic/refresh"] or vim.lsp.handlers["workspace/diagnostic/refresh"]
  client.handlers["workspace/diagnostic/refresh"] = function(err, result, ctx, config)
    local response = refresh(err, result, ctx, config)
    -- Neovim refreshes workspace reports only; dynamic libraries also invalidate document reports.
    if not err and client:supports_method("textDocument/diagnostic") then
      for bufnr in pairs(client.attached_buffers) do
        vim.lsp.diagnostic._refresh(bufnr, client.id)
      end
    end
    return response
  end
end

return M
