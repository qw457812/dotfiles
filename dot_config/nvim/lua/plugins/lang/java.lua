if not LazyVim.has_extra("lang.java") and not U.has_user_extra("lang.nvim-java") then
  return {}
end

-- https://github.com/sykesm/dotfiles/blob/92169d9a6ca596fddc58ce1771d708e92d779dec/.config/nvim/lua/sykesm/plugins/nvim-jdtls.lua#L39
local function java_runtimes()
  local function java_home_macos(version)
    local java_home = "/usr/libexec/java_home"
    if vim.fn.has("macunix") == 0 or vim.fn.executable(java_home) == 0 then
      return
    end
    local res = vim.system({ java_home, "-F", "-v", version }, { text = true }):wait()
    return res.code == 0 and res.stdout:gsub("[\r\n]+$", "")
  end

  local runtimes = {}
  for i = 8, 23 do
    local version = tostring(i)
    local home = java_home_macos(version)
    if not home and version == "8" then
      home = java_home_macos("1.8")
    end
    if home then
      -- note that the field `name` must be a valid `ExecutionEnvironment`
      table.insert(runtimes, {
        name = "JavaSE-" .. (version == "8" and "1.8" or version),
        path = home,
      })
    end
  end
  return runtimes
end

return {
  {
    "LazyVim/LazyVim",
    opts = function()
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

  -- https://github.com/AstroNvim/astrocommunity/tree/main/lua/astrocommunity/pack/java
  -- https://github.com/mfussenegger/dotfiles/blob/fa827b77f354b0f31a8352a27cfc1d9a4973a31c/vim/dot-config/nvim/ftplugin/java.lua
  -- https://github.com/MeanderingProgrammer/dotfiles/blob/d29d911a30eb5371c620f543e336bcbc628d45b0/.config/nvim/lua/mp/plugins/lang/java.lua
  -- https://github.com/doctorfree/nvim-lazyman/blob/bbecf74deb10a0483742196b23b91858f823f632/ftplugin/java.lua
  {
    "mfussenegger/nvim-jdtls",
    commit = vim.g.user_is_termux and "e129398e171e87c0d9e94dd5bea7eb4730473ffc" or nil,
    optional = true,
    opts = function(_, opts)
      local runtimes = java_runtimes()
      return U.extend_tbl(opts, {
        -- https://github.com/eclipse-jdtls/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
        settings = {
          java = {
            eclipse = { downloadSources = true },
            configuration = {
              updateBuildConfiguration = "interactive",
              runtimes = not vim.tbl_isempty(runtimes) and runtimes or nil,
            },
            maven = { downloadSources = true },
            implementationsCodeLens = { enabled = true },
            referencesCodeLens = { enabled = true },
            signatureHelp = { enabled = true },
            completion = {
              favoriteStaticMembers = {
                "org.hamcrest.MatcherAssert.assertThat",
                "org.hamcrest.Matchers.*",
                "org.hamcrest.CoreMatchers.*",
                "org.junit.jupiter.api.Assertions.*",
                "java.util.Objects.requireNonNull",
                "java.util.Objects.requireNonNullElse",
                "org.mockito.Mockito.*",
              },
            },
            contentProvider = { preferred = "fernflower" },
            sources = {
              organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
              },
            },
            codeGeneration = {
              toString = {
                template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
              },
              useBlocks = true,
            },
            -- format = {
            --   settings = { -- you can use your preferred format style
            --     url = "https://raw.githubusercontent.com/google/styleguide/gh-pages/eclipse-java-google-style.xml", -- intellij-java-google-style.xml
            --     profile = "GoogleStyle",
            --   },
            -- },
            saveActions = {
              -- To disable format and organize imports on save for specific projects,
              -- create a `.lazy.lua` file in your project with following content:
              -- ```lua
              --    vim.g.autoformat = false
              --
              --    return {}
              -- ```
              organizeImports = vim.g.autoformat, -- TODO: respect <leader>uf toggle
            },
          },
        },
        jdtls = function(config)
          config.cmd = vim.list_extend(vim.deepcopy(config.cmd), {
            "--jvm-arg=-Xms8g",
            "--jvm-arg=-Xmx8g",
          })
          -- dd(config)
        end,
        ---@param args vim.api.create_autocmd.callback.args
        on_attach = function(args)
          require("which-key").add({
            {
              mode = "n",
              buffer = args.buf,
              { "gs", require("jdtls").super_implementation, desc = "Goto Super" },
              { "gS", require("jdtls.tests").goto_subjects, desc = "Goto Subjects" },
              { "<localleader>r", require("jdtls").set_runtime, desc = "Pick Java Runtime" },
            },
          })
        end,
      })
    end,
  },

  {
    "Wansmer/symbol-usage.nvim",
    optional = true,
    opts = function(_, opts)
      LazyVim.extend(opts, "disable.lsp", { "jdtls" })
    end,
  },

  {
    "kosayoda/nvim-lightbulb",
    optional = true,
    opts = function(_, opts)
      LazyVim.extend(opts, "ignore.clients", { "jdtls" })
    end,
  },
}
