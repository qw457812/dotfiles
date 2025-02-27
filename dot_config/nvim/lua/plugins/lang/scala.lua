if not LazyVim.has_extra("lang.scala") then
  return {}
end

return {
  { "scalameta/nvim-metals", optional = true, ft = "java" },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- HACK: add java to filetypes
      -- see: https://github.com/LazyVim/LazyVim/blob/859646f628ff0d99e6afe835ba0a48faed2972af/lua/lazyvim/plugins/extras/lang/scala.lua#L55-L69
      local setup_metals_orig = opts.setup.metals
      opts.setup.metals = function(...)
        local ret = setup_metals_orig(...)

        local autocmds = vim.api.nvim_get_autocmds({
          event = "FileType",
          group = vim.api.nvim_create_augroup("nvim-metals", { clear = false }),
        })
        if #autocmds > 0 then
          local metals_did_attach = false
          LazyVim.lsp.on_attach(function()
            metals_did_attach = true
            ---@diagnostic disable-next-line: redundant-return-value
            return true
          end, "metals")
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "java",
            callback = function()
              if metals_did_attach then
                autocmds[1].callback()
              end
            end,
            group = vim.api.nvim_create_augroup("nvim-metals-java", { clear = true }),
          })
        end

        return ret
      end
    end,
  },
}
