if not LazyVim.has_extra("lang.java") then
  return {}
end

return {
  {
    "LazyVim/LazyVim",
    opts = function()
      -- TODO: use ftplugin
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function()
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
        end,
      })
    end,
  },
}
