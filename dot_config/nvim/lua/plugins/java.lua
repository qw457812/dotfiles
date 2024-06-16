return {
  -- LazyVim Extras: lang.java
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- add lombok support
      -- https://github.com/LazyVim/LazyVim/discussions/275
      -- https://github.com/doctorfree/nvim-lazyman/blob/13c47cc03f6a0fabb2863cfa7fd471ca7ccc384f/ftplugin/java.lua#L150

      -- local JDTLS_LOCATION = vim.fn.expand("$MASON/packages/jdtls")
      -- local JDTLS_LOCATION = require("mason-registry").get_package("jdtls"):get_install_path()
      local JDTLS_LOCATION = vim.fn.stdpath("data") .. "/mason/packages/jdtls"

      -- extend the opts.cmd, see ~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/java.lua
      vim.list_extend(opts.cmd, {
        "--jvm-arg=-javaagent:" .. JDTLS_LOCATION .. "/lombok.jar",
      })
    end,
  },
}
