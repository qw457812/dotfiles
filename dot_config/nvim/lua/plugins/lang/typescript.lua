if not LazyVim.has_extra("lang.typescript") then
  return {}
end

---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      if LazyVim.has_extra("lang.typescript.oxc") then
        vim.api.nvim_create_autocmd("BufWritePost", {
          group = vim.api.nvim_create_augroup("oxlint", { clear = true }),
          callback = function(ev)
            if
              vim.list_contains(
                { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" },
                vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":t")
              ) and #vim.lsp.get_clients({ name = "oxlint" }) > 0
            then
              Snacks.notify("Restarting oxlint...")
              vim.cmd("lsp restart oxlint")
            end
          end,
        })
      end
    end,
  },

  -- TypeScript 7 renamed the `tsgo` lsp to `tsc` (nvim-lspconfig #4493).
  -- LazyVim only accepts `tsgo`/`vtsls` for `vim.g.lazyvim_ts_lsp`, so keep that global
  -- as-is and swap the servers here until LazyVim registers `tsc` itself.
  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      if vim.g.lazyvim_ts_lsp ~= "tsgo" then
        return
      end

      return U.extend_tbl(opts, {
        ---@type table<string, lazyvim.lsp.Config|boolean>
        servers = {
          tsgo = {
            enabled = false,
          },
          -- https://github.com/LazyVim/LazyVim/blob/d07070bf2ff83ae513097d02d71460920af85a91/lua/lazyvim/plugins/extras/lang/typescript/tsgo.lua#L24-L48
          -- https://github.com/neovim/nvim-lspconfig/blob/3fc5c454b5a903049c8096b34e60ed30d1891aae/lsp/tsc.lua#L71-L104
          tsc = {
            filetypes = {
              "javascript",
              "javascriptreact",
              "javascript.jsx",
              "typescript",
              "typescriptreact",
              "typescript.tsx",
            },
            settings = {
              ["js/ts"] = {
                inlayHints = {
                  functionLikeReturnTypes = { enabled = false },
                  variableTypes = { enabled = false },
                },
              },
            },
          },
        },
      } --[[@as PluginLspOpts]])
    end,
  },
}
