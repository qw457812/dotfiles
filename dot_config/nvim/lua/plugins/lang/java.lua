if not LazyVim.has_extra("lang.java") and not U.has_user_extra("lang.nvim-java") then
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

  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = {
      -- https://github.com/eclipse-jdtls/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
      -- https://github.com/doctorfree/nvim-lazyman/blob/bbecf74deb10a0483742196b23b91858f823f632/ftplugin/java.lua#L84
      settings = {
        java = {
          saveActions = {
            organizeImports = true,
          },
        },
      },
      ------@param args vim.api.create_autocmd.callback.args
      ---on_attach = function(args)
      ---  --[[add custom keys here]]
      ---end,
    },
  },
}
