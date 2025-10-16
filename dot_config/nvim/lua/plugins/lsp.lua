local H = {}

--- copied from: https://github.com/neovim/neovim/blob/cf9b36f3d97b6f9c66ffff008bc1b5a5dd14ca98/runtime/lua/vim/lsp/buf.lua#L13-L24
--- @param params? table
--- @return fun(client: vim.lsp.Client): lsp.TextDocumentPositionParams
function H.client_positional_params(params)
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
---@module 'dropbar'
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
--- https://github.com/neovim/neovim/blob/fb6c059dc55c8d594102937be4dd70f5ff51614a/runtime/lua/vim/lsp/_tagfunc.lua#L25
function H.pick_definitions_or_references()
  vim.lsp.buf_request_all(0, "textDocument/definition", H.client_positional_params(), function(results, ctx)
    if vim.tbl_isempty(results) then
      -- no definitions found, try references
      H.pick_references()
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
            H.pick_references()
            return
          end
        else
          result = result --[[@as (lsp.Location[]|lsp.LocationLink[])]]
          for _, item in pairs(result) do
            if H.is_same_position(item, ctx.params) then
              -- already at one of the definitions, go to references
              H.pick_references()
              return
            end
          end
        end
      end
    end
    -- not at any definition, go to definitions
    H.pick_definitions()
  end)
end

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      local Keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- stylua: ignore
      vim.list_extend(Keys, {
        { "K", false },
        -- add `has = "hover"` to prevent rime_ls from overwriting `gk` in help pages
        { "gk", function() return vim.lsp.buf.hover() end, desc = "Hover", has = "hover" },
        { "<c-k>", mode = "i", false }, -- <c-k> for cmp navigation
        { "<c-h>", function() return vim.lsp.buf.signature_help() end, mode = "i", desc = "Signature Help", has = "signatureHelp" }, -- can conflict with mini.snippets
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
        -- https://zed.dev/docs/vim#language-server
        { "cd", "<leader>cr", desc = "Rename (change definition)", has = "rename", remap = true },
        -- TODO: conflict with goto_super_method in java/scala files
        { "gs", "<leader>ss", desc = "LSP Symbols", has = "documentSymbol", remap = true },
        { "gS", "<leader>sS", desc = "LSP Workspace Symbols", has = "workspace/symbols", remap = true },
        { "<leader>cl", false },
        -- { "<leader>il", "<cmd>LspInfo<cr>", desc = "Lsp" },
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

      -- opts.folds.enabled
      LazyVim.lsp.on_supports_method("textDocument/foldingRange", function(client, buffer)
        local fname = vim.api.nvim_buf_get_name(buffer)
        if vim.o.diff or fname:match("/%.metals/readonly/dependencies/") then
          return
        end
        if LazyVim.set_default("foldmethod", "expr") then
          LazyVim.set_default("foldexpr", "v:lua.vim.lsp.foldexpr()")
        end
      end)

      return U.extend_tbl(opts, {
        ---@type vim.diagnostic.Opts
        diagnostics = {
          virtual_text = not LazyVim.has("tiny-inline-diagnostic.nvim") and {
            prefix = "icons",
            current_line = true,
          } --[[@as vim.diagnostic.Opts.VirtualText]],
        },
        folds = { enabled = false }, -- set up on our own above
      } --[[@as PluginLspOpts]])
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
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "help", "man", "checkhealth" },
        callback = function(ev)
          vim.keymap.set("n", "gs", "gO", { buffer = ev.buf, silent = true, remap = true, desc = "Show Outline" })
        end,
      })
    end,
  },

  {
    "saecki/live-rename.nvim",
    lazy = true,
    specs = {
      {
        "neovim/nvim-lspconfig",
        opts = function()
          local Keys = require("lazyvim.plugins.lsp.keymaps").get()
          vim.list_extend(Keys, {
            {
              "<leader>cr",
              function()
                local live_rename = require("live-rename")
                live_rename.rename()

                local buf = vim.api.nvim_get_current_buf()
                -- see: https://github.com/saecki/live-rename.nvim/blob/78fcdb4072c6b1a8e909872f9a971b2f2b642d1e/lua/live-rename.lua#L467
                if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t") == "lsp:rename" then
                  vim.b[buf].completion = false -- disable blink.cmp in favor of <cr>
                  vim.keymap.set({ "n", "i" }, "<C-s>", live_rename.submit, { buffer = buf, desc = "Submit rename" })
                  vim.keymap.set("n", "<C-c>", live_rename.hide, { buffer = buf, desc = "Cancel rename" })
                  vim.keymap.set("i", "<C-c>", function()
                    vim.cmd("stopinsert")
                    live_rename.hide()
                  end, { buffer = buf, desc = "Cancel rename" })
                end
              end,
              desc = "Rename (live-rename.nvim)",
              has = "rename",
            },
          })
        end,
      },
    },
  },

  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          lsp_symbols = {
            confirm = function(...)
              -- HACK: fix the error occurring in the jdtls class buffer when neo-tree is open:
              -- vim.schedule callback: https://github.com/folke/snacks.nvim/blob/3d695ab7d062d40c980ca5fd9fe6e593c8f35b12/lua/snacks/picker/actions.lua#L128: Cursor position outside buffer
              -- see: https://github.com/folke/snacks.nvim/commit/4551f499c7945036761fd48927cc07b9720fce56
              local main = require("snacks.picker.core.main").new({ float = false, file = false })
              vim.api.nvim_set_current_win(main:get())

              -- original confirm action
              Snacks.picker.actions.confirm(...)
            end,
          },
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    optional = true,
    ---@module "mason"
    ---@type MasonSettings
    opts = {
      ui = {
        width = vim.g.user_is_termux and 1 or nil,
        height = vim.g.user_is_termux and 1 or nil,
        keymaps = {
          uninstall_package = "x",
          apply_language_filter = "f",
          toggle_help = "?",
        },
      },
    },
  },

  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      -- https://github.com/folke/noice.nvim/wiki/Configuration-Recipes#ignore-certain-lsp-servers-for-progress-messages
      table.insert(opts.routes, {
        filter = {
          event = "lsp",
          kind = "progress",
          cond = function(message)
            -- dd(vim.tbl_get(message.opts, "progress"))
            return vim.g.user_suppress_lsp_progress == true
          end,
        },
        opts = { skip = true },
      })
      table.insert(opts.routes, {
        filter = {
          event = "notify",
          find = "^No information available$", -- hover by `K`
        },
        view = "mini",
      })
    end,
  },
}
