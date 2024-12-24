local lsp = vim.lsp
local util = lsp.util
local ms = lsp.protocol.Methods

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
--- https://github.com/neovim/neovim/blob/fb6c059dc55c8d594102937be4dd70f5ff51614a/runtime/lua/vim/lsp/_tagfunc.lua#L42
---@param result lsp.Location|lsp.LocationLink
---@param params lsp.TextDocumentPositionParams
---@return boolean
local function is_same_position(result, params)
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
local function pick_definitions_or_references()
  local params = util.make_position_params()
  local method = ms.textDocument_definition
  local results_by_client, err = lsp.buf_request_sync(0, method, params, 1000)
  if err or not results_by_client then
    LazyVim.error(string.format("Error executing '%s': %s", method, err), { title = "LSP" })
    return
  end
  if vim.tbl_isempty(results_by_client) then
    -- no definitions found, try references
    pick_references()
  else
    for _, lsp_results in pairs(results_by_client) do
      local result = lsp_results.result or {}
      if result.range then -- Location
        if is_same_position(result, params) then
          -- already at one of the definitions, go to references
          pick_references()
          return
        end
      else
        result = result --[[@as (lsp.Location[]|lsp.LocationLink[])]]
        for _, item in pairs(result) do
          if is_same_position(item, params) then
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
  { "saecki/live-rename.nvim", lazy = true },
  -- LSP Keymaps
  -- https://www.lazyvim.org/plugins/lsp#%EF%B8%8F-customizing-lsp-keymaps
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/telescope.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/fzf.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/lsp/keymaps.lua
  -- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/inc-rename.lua
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local Keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- stylua: ignore
      vim.list_extend(Keys, {
        { "K", false },
        { "gk", function() return vim.lsp.buf.hover() end, desc = "Hover" },
        { "<c-k>", mode = "i", false }, -- <c-k> for cmp navigation
        { "<c-h>", function() return vim.lsp.buf.signature_help() end, mode = "i", desc = "Signature Help", has = "signatureHelp" },
        -- { "gd", pick_definitions_or_references, desc = "Goto Definition/References", has = "definition" },
        {
          "<cr>",
          pick_definitions_or_references,
          desc = "Goto Definition/References",
          has = "definition",
          cond = function()
            if vim.bo.filetype == "markdown" then
              -- for gaoDean/autolist.nvim
              return false
            end
            -- check to see if `<cr>` is already mapped to the buffer (avoids overwriting)
            -- for yarospace/lua-console.nvim
            for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
              ---@diagnostic disable-next-line: undefined-field
              if map.lhs and map.lhs:lower() == "<cr>" then
                return false
              end
            end
            return true
          end,
        },
        { "<leader>cr", function() require("live-rename").rename() end, desc = "Rename (live-rename.nvim)", has = "rename" },
        -- https://github.com/jacquin236/minimal-nvim/blob/baacb78adce67d704d17c3ad01dd7035c5abeca3/lua/plugins/lsp.lua
        { "<leader>cl", false },
        { "<leader>il", "<cmd>checkhealth lspconfig<cr>", desc = "Lsp" },
        { "<leader>clr", "<cmd>LspRestart<cr>", desc = "Restart Lsp" },
        { "<leader>cls", "<cmd>LspStart<cr>", desc = "Start Lsp" },
        { "<leader>clS", "<cmd>LspStop<cr>", desc = "Stop Lsp" },
        { "<leader>clW", function() vim.lsp.buf.remove_workspace_folder() end, desc = "Remove Workspace" },
        { "<leader>clw", function() vim.lsp.buf.add_workspace_folder() end, desc = "Add Workspace" },
        { "<leader>clL", function()
          LazyVim.info(vim.tbl_map(U.path.home_to_tilde, vim.lsp.buf.list_workspace_folders()), { title = "Lsp Workspaces" })
        end, desc = "List Workspace" },
      })

      if vim.g.user_is_termux then
        opts.servers.lua_ls = opts.servers.lua_ls or {}
        opts.servers.lua_ls.mason = false -- pkg install lua-language-server
      end
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
      -- :=LazyVim.opts("mason.nvim").ensure_installed
      ensure_installed = {
        "selene",
        "luacheck",
      },
    },
  },
}
