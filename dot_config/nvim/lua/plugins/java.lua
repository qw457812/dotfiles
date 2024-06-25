-- require lazyvim.plugins.extras.lang.java
-- ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/java.lua
return {
  -- add lombok support
  -- https://github.com/LazyVim/LazyVim/discussions/275
  -- https://github.com/doctorfree/nvim-lazyman/blob/13c47cc03f6a0fabb2863cfa7fd471ca7ccc384f/ftplugin/java.lua#L150
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- alternative to `LazyVim.get_pkg_path("jdtls")`
      -- - vim.fn.expand("$MASON/packages/jdtls")
      -- - require("mason-registry").get_package("jdtls"):get_install_path()
      -- - vim.fn.stdpath("data") .. "/mason/packages/jdtls"

      -- extend the opts.cmd
      table.insert(opts.cmd, "--jvm-arg=-javaagent:" .. LazyVim.get_pkg_path("jdtls") .. "/lombok.jar")
    end,
  },
}
