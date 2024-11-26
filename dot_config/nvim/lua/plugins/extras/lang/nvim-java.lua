if LazyVim.has_extra("lang.java") then
  return {}
end

-- https://github.com/nvim-java/nvim-java/wiki/Lazyvim
-- https://github.com/nvim-java/starter-lazyvim/blob/main/lua/plugins/java/init.lua
-- https://github.com/s1n7ax/lazyvim-dotnvim/blob/main/lua/plugins/java/init.lua
-- https://github.com/LazyVim/LazyVim/pull/2211
-- https://github.com/appelgriebsch/Nv/blob/main/lua/plugins/extras/lang/java.lua
-- https://github.com/nvim-java/starter-astronvim
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "java" } },
  },

  {
    "nvim-java/nvim-java",
    config = false,
    dependencies = {
      {
        "neovim/nvim-lspconfig",
        opts = {
          servers = {
            -- Your JDTLS configuration goes here
            jdtls = {
              -- settings = {
              --   java = {
              --     configuration = {
              --       runtimes = {
              --         {
              --           name = "JavaSE-23",
              --           path = "/usr/local/sdkman/candidates/java/23-tem",
              --         },
              --       },
              --     },
              --   },
              -- },
              -- stylua: ignore
              keys = {
                -- TODO: https://github.com/nvim-java/nvim-java/wiki/Tips-&-Tricks
                -- jdtls on_attach
                -- :FzfLua lsp_live_workspace_symbols
                { "<leader>cx", "", desc = "+extract" },
                { "<leader>cxv", mode = { "n", "x" }, function() require("java").refactor.extract_variable_all_occurrence() end, desc = "Extract Variable (Java)" },
                { "<leader>cxc", mode = { "n", "x" }, function() require("java").refactor.extract_constant() end, desc = "Extract Constant (Java)" },
                { "<leader>cxm", mode = { "n", "x" }, function() require("java").refactor.extract_method() end, desc = "Extract Method (Java)" },
                { "<leader>cxf", mode = { "n", "x" }, function() require("java").refactor.extract_field() end, desc = "Extract Field (Java)" },
                {
                  "<leader>co",
                  function()
                    vim.lsp.buf.code_action({
                      context = { only = { "source.organizeImports" } },
                      apply = true,
                    })
                  end,
                  desc = "Organize Imports (Java)",
                },
                -- Workaround for the lack of neotest-java support in nvim-java (https://github.com/nvim-java/nvim-java/issues/97)
                { "<leader>td", function() require("java").test.debug_current_method() end, desc = "Debug Nearest (Java)" },
                { "<leader>tr", function() require("java").test.run_current_method() end, desc = "Run Nearest (Java)" },
                { "<leader>tt", function() require("java").test.run_current_class() end, desc = "Run File (Java)" },
                { "<leader>to", function() require("java").test.view_last_report() end, desc = "Show Output (Java)" },
              },
            },
          },
          setup = {
            jdtls = function()
              local has_dap = LazyVim.has("nvim-dap")

              -- Your nvim-java configuration goes here
              require("java").setup({
                java_test = {
                  enable = has_dap,
                },
                java_debug_adapter = {
                  enable = has_dap,
                },
                -- spring_boot_tools = {
                --   enable = false,
                -- },
                jdk = {
                  auto_install = false,
                },
              })
            end,
          },
        },
      },
    },
    specs = {
      { "mfussenegger/nvim-jdtls", optional = true, enabled = false },
    },
  },
}
