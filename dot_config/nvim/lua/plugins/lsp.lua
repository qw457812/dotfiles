local H = {}

---Check if cursor is in range
---copied from: https://github.com/Bekaboo/dropbar.nvim/blob/5439d2f02bb744cecb878aaa23c6c6f8b21a351c/lua/dropbar/sources/lsp.lua#L97-L115
---@param cursor integer[] cursor position (line, character); (1, 0)-based
---@param range lsp_range_t 0-based range
---@return boolean
function H.cursor_in_range(cursor, range)
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

function H.pick_definitions()
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").lsp_definitions({ reuse_win = true })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").lsp_definitions({ jump_to_single_result = true, ignore_current_line = true })
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.lsp_definitions()
  end
end

function H.pick_references()
  if LazyVim.pick.picker.name == "telescope" then
    require("telescope.builtin").lsp_references({ include_declaration = false })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").lsp_references({ jump_to_single_result = true, ignore_current_line = true })
  elseif LazyVim.pick.picker.name == "snacks" then
    Snacks.picker.lsp_references()
  end
end

--- Is the result's location the same as the params location?
--- https://github.com/mrcjkb/haskell-tools.nvim/blob/6b6fa211da47582950abfab9e893ab936b6c4298/lua/haskell-tools/lsp/hover.lua#L105
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

--- Go to definition or references if already at definition, like `gd` in vscode and idea but slightly different.
--- https://github.com/ray-x/navigator.lua/blob/db3ac40bd4793abf90372687e35ece1c8969acc9/lua/navigator/definition.lua#L62
--- https://github.com/mrcjkb/haskell-tools.nvim/blob/6b6fa211da47582950abfab9e893ab936b6c4298/lua/haskell-tools/lsp/hover.lua#L188
--- https://github.com/fcying/dotvim/blob/47c7f8faa600e1045cc4ac856d639f5f23f00cf4/lua/util.lua#L146
--- https://github.com/mbriggs/nvim-v2/blob/d8526496596f3a4dcab2cde86674ca58eaee65e2/lsp_fixcurrent.lua
--- https://github.com/neovim/neovim/blob/fb6c059dc55c8d594102937be4dd70f5ff51614a/runtime/lua/vim/lsp/_tagfunc.lua#L25
--- https://github.com/ibhagwan/fzf-lua/blob/975534f4861e2575396716225c1202572645583d/lua/fzf-lua/providers/lsp.lua#L468
function H.pick_definitions_or_references()
  local params = vim.lsp.util.make_position_params(0, "utf-16")
  local method = vim.lsp.protocol.Methods.textDocument_definition
  local results_by_client, err = vim.lsp.buf_request_sync(0, method, params, 1000)
  if err or not results_by_client then
    LazyVim.error(string.format("Error executing '%s': %s", method, err), { title = "LSP" })
    return
  end
  if vim.tbl_isempty(results_by_client) then
    -- no definitions found, try references
    H.pick_references()
  else
    for _, lsp_results in pairs(results_by_client) do
      local result = lsp_results.result or {}
      if result.range then -- Location
        if H.is_same_position(result, params) then
          -- already at one of the definitions, go to references
          H.pick_references()
          return
        end
      else
        result = result --[[@as (lsp.Location[]|lsp.LocationLink[])]]
        for _, item in pairs(result) do
          if H.is_same_position(item, params) then
            -- already at one of the definitions, go to references
            H.pick_references()
            return
          end
        end
      end
    end
    -- not at any definition, go to definitions
    H.pick_definitions()
  end
end

return {
  { "saecki/live-rename.nvim", lazy = true },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local Keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- stylua: ignore
      vim.list_extend(Keys, {
        { "K", false },
        -- add `has = "hover"` to prevent rime_ls from overwriting `gk` in help pages
        { "gk", function() return vim.lsp.buf.hover() end, desc = "Hover", has = "hover" },
        -- { "<c-k>", mode = "i", false }, -- <c-k> for cmp navigation
        -- { "<c-h>", function() return vim.lsp.buf.signature_help() end, mode = "i", desc = "Signature Help", has = "signatureHelp" }, -- conflicts with mini.snippets
        -- { "gd", H.pick_definitions_or_references, desc = "Goto Definition/References", has = "definition" },
        {
          "<cr>",
          H.pick_definitions_or_references,
          desc = "Goto Definition/References",
          has = "definition",
          cond = function()
            if vim.bo.filetype == "markdown" then
              -- for gaoDean/autolist.nvim
              return false
            end
            -- check to see if `<cr>` is already mapped to the buffer (avoids overwriting)
            -- for yarospace/lua-console.nvim
            return not U.keymap.buffer_local_mapping_exists(0, "n", "<cr>")
          end,
        },
        { "<leader>cr", function() require("live-rename").rename() end, desc = "Rename (live-rename.nvim)", has = "rename" },
        { "<leader>cl", false },
        -- { "<leader>il", "<cmd>checkhealth lspconfig<cr>", desc = "Lsp" },
        { "<leader>il", function() Snacks.picker.lsp_config() end, desc = "Lsp" },
        { "<leader>clr", "<cmd>LspRestart<cr>", desc = "Restart Lsp" },
        { "<leader>cls", "<cmd>LspStart<cr>", desc = "Start Lsp" },
        { "<leader>clS", "<cmd>LspStop<cr>", desc = "Stop Lsp" },
        { "<leader>clW", function() vim.lsp.buf.remove_workspace_folder() end, desc = "Remove Workspace" },
        { "<leader>clw", function() vim.lsp.buf.add_workspace_folder() end, desc = "Add Workspace" },
        {
          "<leader>clL",
          function()
            LazyVim.info(vim.tbl_map(U.path.home_to_tilde, vim.lsp.buf.list_workspace_folders()), { title = "Lsp Workspaces" })
          end,
          desc = "List Workspace",
        },
      })

      if LazyVim.pick.picker.name == "snacks" then
        vim.list_extend(Keys, {
          {
            "<leader>ss",
            function()
              -- see: https://github.com/folke/snacks.nvim/issues/1057#issuecomment-2652052218
              -- copied from: https://github.com/disrupted/dotfiles/blob/60e5eff02e2f4aff30dae259cdebdfe172b8e6fe/.config/nvim/lua/plugins/plugins.lua#L181-L253
              local cursor = vim.api.nvim_win_get_cursor(0)
              local picker = Snacks.picker.lsp_symbols({ filter = LazyVim.config.kind_filter })
              -- focus the symbol at the cursor position
              picker.matcher.task:on(
                "done",
                vim.schedule_wrap(function()
                  for symbol in vim.iter(picker:items()):rev() do
                    if H.cursor_in_range(cursor, symbol.range) then
                      picker.list:move(symbol.idx, true)
                      return
                    end
                  end
                end)
              )
            end,
            desc = "LSP Symbols",
            has = "documentSymbol",
          },
        })
      end

      return U.extend_tbl(opts, {
        -- setting `vim.diagnostic.config({ virtual_text = false })` for tiny-inline-diagnostic.nvim
        -- see: https://github.com/LazyVim/LazyVim/blob/1e83b4f843f88678189df81b1c88a400c53abdbc/lua/lazyvim/plugins/lsp/init.lua#L177
        diagnostics = { virtual_text = not LazyVim.has("tiny-inline-diagnostic.nvim") and { prefix = "icons" } },
        servers = {
          lua_ls = {
            mason = not vim.g.user_is_termux and nil, -- run `pkg install lua-language-server` on termux
            -- https://luals.github.io/wiki/settings/
            -- https://github.com/LuaLS/lua-language-server/blob/12013babf4e386bdde1b21af57a2a06b6e127703/locale/zh-cn/setting.lua
            settings = {
              Lua = {
                -- hover = { expandAlias = false },
                type = {
                  castNumberToInteger = true,
                  inferParamType = true,
                },
                -- diagnostics = {
                --   disable = { "incomplete-signature-doc", "trailing-space" },
                --   groupSeverity = {
                --     strong = "Warning",
                --     strict = "Warning",
                --   },
                --   groupFileStatus = {
                --     ["ambiguity"] = "Opened",
                --     ["await"] = "Opened",
                --     ["codestyle"] = "None",
                --     ["duplicate"] = "Opened",
                --     ["global"] = "Opened",
                --     ["luadoc"] = "Opened",
                --     ["redefined"] = "Opened",
                --     ["strict"] = "Opened",
                --     ["strong"] = "Opened",
                --     ["type-check"] = "Opened",
                --     ["unbalanced"] = "Opened",
                --     ["unused"] = "Opened",
                --   },
                --   unusedLocalExclude = { "_*" },
                -- },
              },
            },
          },
        },
      })
    end,
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>cl", group = "Lsp", icon = { icon = " ", color = "purple" } },
      },
    },
  },
  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      table.insert(opts.routes, {
        filter = {
          event = "notify",
          find = "^No information available$", -- hover by `K`
        },
        view = "mini",
      })

      if vim.fn.has("nvim-0.11") == 1 then
        table.insert(opts.routes, {
          filter = {
            event = "notify",
            any = {
              {
                find = "^position_encoding param is required in vim%.lsp%.util%.make_position_params%. Defaulting to position encoding of the first client%.$",
              },
              {
                find = "^warning: multiple different client offset_encodings detected for buffer, vim%.lsp%.util%._get_offset_encoding%(%) uses the offset_encoding from the first client$",
              },
            },
          },
          view = "mini",
        })
      end
    end,
  },

  -- https://github.com/folke/dot/blob/13b8ed8d40755b58163ffff30e6a000d06fc0be0/nvim/lua/plugins/lsp.lua#L79
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        lua = { "selene", "luacheck" },
      },
      linters = {
        selene = {
          -- `condition` is a LazyVim extension that allows you to dynamically enable/disable linters based on the context
          condition = function(ctx)
            local root = LazyVim.root.get({ normalize = true })
            if root ~= vim.uv.cwd() then
              return false
            end
            return vim.fs.find({ "selene.toml" }, { path = root, upward = true })[1]
          end,
        },
        luacheck = {
          condition = function(ctx)
            local root = LazyVim.root.get({ normalize = true })
            if root ~= vim.uv.cwd() then
              return false
            end
            return vim.fs.find({ ".luacheckrc" }, { path = root, upward = true })[1]
          end,
        },
      },
    },
  },

  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "selene",
        "luacheck",
      },
    },
  },
}
