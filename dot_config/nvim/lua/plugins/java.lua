-- require lazyvim.plugins.extras.lang.java
return {
  -- feat(java): enable Lombok support in jdtls ([#3852](https://github.com/LazyVim/LazyVim/issues/3852)) ([0fede40](https://github.com/LazyVim/LazyVim/commit/0fede4040b15da7e74c6a741132ff3d48634c1ad))
  -- -- add lombok support
  -- -- https://github.com/LazyVim/LazyVim/discussions/275
  -- -- https://github.com/doctorfree/nvim-lazyman/blob/13c47cc03f6a0fabb2863cfa7fd471ca7ccc384f/ftplugin/java.lua#L150
  -- {
  --   "mfussenegger/nvim-jdtls",
  --   optional = true,
  --   opts = function(_, opts)
  --     -- alternative to `LazyVim.get_pkg_path("jdtls")`
  --     -- - vim.fn.expand("$MASON/packages/jdtls")
  --     -- - require("mason-registry").get_package("jdtls"):get_install_path()
  --     -- - vim.fn.stdpath("data") .. "/mason/packages/jdtls"
  --
  --     -- extend the opts.cmd
  --     table.insert(opts.cmd, "--jvm-arg=-javaagent:" .. LazyVim.get_pkg_path("jdtls") .. "/lombok.jar")
  --   end,
  -- },
}
