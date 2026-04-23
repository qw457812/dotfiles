if not LazyVim.has_extra("lang.json") then
  return {}
end

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      ---@type table<string, lazyvim.lsp.Config|boolean>
      servers = {
        jsonls = {
          filetypes = { "json", "jsonc", "json5" }, -- add json5
        },
      },
    },
  },
}
