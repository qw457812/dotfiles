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
              vim.api.nvim_buf_get_name(ev.buf):find(".oxlintrc") and #vim.lsp.get_clients({ name = "oxlint" }) > 0
            then
              Snacks.notify("Restarting oxlint...")
              vim.cmd("lsp restart oxlint")
            end
          end,
        })
      end
    end,
  },
}
