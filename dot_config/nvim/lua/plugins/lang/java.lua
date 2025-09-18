if not LazyVim.has_extra("lang.java") and not U.has_user_extra("lang.nvim-java") then
  return {}
end

---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function(ev)
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4

          local _, _, class = U.java.parse_jdt_uri(ev.file)
          if class then
            vim.b[ev.buf].user_lualine_filename = class .. ".class"
            vim.b[ev.buf].user_bufferline_name = class
          end
        end,
      })
    end,
  },

  -- TODO: not sure what it's for
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "javadoc" } },
  },

  -- https://github.com/AstroNvim/astrocommunity/tree/main/lua/astrocommunity/pack/java
  -- https://github.com/mfussenegger/dotfiles/blob/fa827b77f354b0f31a8352a27cfc1d9a4973a31c/vim/dot-config/nvim/ftplugin/java.lua
  -- https://github.com/MeanderingProgrammer/dotfiles/blob/d29d911a30eb5371c620f543e336bcbc628d45b0/.config/nvim/lua/mp/plugins/lang/java.lua
  -- https://github.com/doctorfree/nvim-lazyman/blob/bbecf74deb10a0483742196b23b91858f823f632/ftplugin/java.lua
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      return U.extend_tbl(opts, {
        -- https://github.com/eclipse-jdtls/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
        settings = {
          java = {
            eclipse = { downloadSources = true },
            configuration = {
              updateBuildConfiguration = "interactive",
              runtimes = U.java.jdt_java_runtimes(),
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
              --    if vim.g.autoformat == false then
              --      return {}
              --    end
              --
              --    -- disable autoformat for current project
              --    vim.g.autoformat = false
              --
              --    local local_spec = vim.fs.root(0, ".lazy.lua") -- current .lazy.lua file
              --    vim.api.nvim_create_autocmd("BufReadPost", {
              --      group = vim.api.nvim_create_augroup("local_spec_autoformat", { clear = true }),
              --      callback = function(ev)
              --        if vim.fs.root(ev.buf, ".lazy.lua") == local_spec and vim.fn.fnamemodify(ev.file, ":t") ~= ".lazy.lua" then
              --          return -- current project and not the .lazy.lua file
              --        end
              --
              --        -- but do not disable autoformat for other projects, like dotfiles
              --        if vim.b[ev.buf].autoformat == nil then
              --          vim.b[ev.buf].autoformat = true
              --        end
              --      end,
              --    })
              --
              --    return {}
              -- ```
              organizeImports = vim.g.autoformat, -- TODO: respect <leader>uf toggle
            },
          },
        },
        jdtls = function(config)
          if not vim.g.user_is_termux then
            config.cmd = vim.list_extend(vim.deepcopy(config.cmd), {
              "--jvm-arg=-Xms8g",
              "--jvm-arg=-Xmx16g",
            })
          end

          config.handlers = config.handlers or {}
          -- config.handlers["$/progress"] = function() end -- disable progress updates
          config.handlers["language/status"] = function() end -- mute; having progress reports is enough

          if LazyVim.has("spring-boot.nvim") then
            config.init_options = config.init_options or {}
            config.init_options.bundles =
              vim.list_extend(vim.deepcopy(config.init_options.bundles or {}), require("spring_boot").java_extensions())
          end
        end,
        ---@module "lazyvim"
        ---@param args vim.api.create_autocmd.callback.args
        on_attach = function(args)
          local wk = require("which-key")
          wk.add({
            {
              mode = "n",
              buffer = args.buf,
              { "<leader>cgs", desc = "which_key_ignore" },
              { "<leader>cgS", desc = "which_key_ignore" },
              { "gs", require("jdtls").super_implementation, desc = "Goto Super" },
              { "gS", require("jdtls.tests").goto_subjects, desc = "Goto Subjects" },
              { "<leader>rx", require("jdtls").extract_variable_all, desc = "Extract Variable" },
              { "<leader>rC", require("jdtls").extract_constant, desc = "Extract Constant" },
              { "<localleader>r", require("jdtls").set_runtime, desc = "Pick Java Runtime" },
            },
          })
          -- stylua: ignore
          wk.add({
            {
              mode = "v",
              buffer = args.buf,
              { "<leader>rf", [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]], desc = "Extract Method" },
              { "<leader>rx", [[<ESC><CMD>lua require('jdtls').extract_variable_all(true)<CR>]], desc = "Extract Variable" },
              { "<leader>rC", [[<ESC><CMD>lua require('jdtls').extract_constant(true)<CR>]], desc = "Extract Constant" },
            },
          })
        end,
      })
    end,
  },

  -- TODO: this should not be needed
  -- https://github.com/LazyVim/LazyVim/blob/c05392186e9e540d4af169922c333b5baa583cbe/lua/lazyvim/plugins/extras/lang/java.lua#L65-L80
  -- https://github.com/LazyVim/LazyVim/commit/773f28b4912d5505a21da9686d56ab7cf41a9be7
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "jdtls" } },
  },

  -- https://github.com/AstroNvim/astrocommunity/blob/5f74d5fb8d8dc9b8e2904846809121068d7afaca/lua/astrocommunity/pack/spring-boot/init.lua
  {
    "JavaHello/spring-boot.nvim",
    enabled = not vim.g.user_is_termux,
    ft = {
      "java",
      -- "yaml",
      "jproperties",
    },
    ---@type bootls.Config|{}
    opts = {},
    specs = {
      {
        "mason-org/mason.nvim",
        opts = { ensure_installed = { "vscode-spring-boot-tools" } },
      },
    },
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
