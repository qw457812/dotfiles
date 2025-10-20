if not LazyVim.has_extra("lang.scala") then
  return {}
end

local metals_keys ---@type string[]?

---@type LazySpec
return {
  {
    "scalameta/nvim-metals",
    optional = true,
    keys = function(_, keys)
      metals_keys = vim.deepcopy(keys)
      return {}
    end,
    ft = { "scala", "sbt" },
    opts = function(_, opts)
      local has_dap = LazyVim.has("nvim-dap")

      -- https://github.com/ckipp01/dots/blob/c9e829c15a64ca1febe4ebc7544997974e0e5952/nvim/.config/nvim/lua/mesopotamia/lsp.lua#L42
      return U.extend_tbl(opts, {
        tvp = {
          icons = {
            enabled = true,
          },
        },
        settings = {
          -- serverVersion = "latest.snapshot", -- run `:MetalsUpdate` after changing this
          autoImportBuild = "all", -- initial
          defaultBspToBuildTool = true, -- see also: https://github.com/scalameta/metals/discussions/4505
          inlayHints = {
            byNameParameters = { enable = true },
            hintsInPatternMatch = { enable = true },
            implicitArguments = { enable = true },
            implicitConversions = { enable = true },
            inferredTypes = { enable = true },
            typeParameters = { enable = true },
          },
          -- https://scalameta.org/metals/docs/integrations/new-editor#starting-the-server
          serverProperties = {
            "-Xss4m",
            "-Xms8g",
            "-Xmx16g",
          },
          -- https://scalacenter.github.io/bloop/docs/server-reference#custom-java-options
          bloopJvmProperties = {
            "-Xss4m",
            "-Xms8g",
            "-Xmx16g",
          },
        },
        -- https://scalameta.org/metals/docs/integrations/new-editor#initializationoptions
        init_options = {
          icons = "unicode",
        },
        on_attach = function()
          if has_dap then
            require("metals").setup_dap()
          end
        end,
      })
    end,
    config = function(_, metals_config)
      local metals_did_attach = false
      LazyVim.lsp.on_attach(function()
        metals_did_attach = true
        ---@diagnostic disable-next-line: redundant-return-value
        return true
      end, "metals")

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nvim-metals", { clear = true }),
        pattern = { "scala", "sbt", "java" },
        callback = function(ev)
          if ev.match == "java" and not metals_did_attach then
            return
          end
          require("metals").initialize_or_attach(metals_config)
        end,
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      if not LazyVim.has("nvim-metals") then
        return
      end

      -- stylua: ignore
      local keys = vim.list_extend(metals_keys or {}, {
        { "gs", function() require("metals").goto_super_method() end, desc = "Goto Super (Metals)" },
        { "gk", function() require("metals").type_of_range() end, desc = "Type of Range (Metals)", mode = "x" },
        { "<leader>co", function() require("metals").organize_imports() end, desc = "Organize Imports (Metals)" },
        { "<leader>im", function() require("metals").info() end, desc = "Metals" },
        { "<leader>m", "", desc = "+metals" },
        -- NOTE: need to run `:MetalsUpdate` to update (re-install) to the latest stable version or `opts.servers.metals.settings.serverVersion` of metals (~/.cache/nvim/nvim-metals/metals)
        { "<leader>mu", "<cmd>MetalsUpdate<cr>", desc = "Update Metals" },
        { "<leader>mm", function() require("metals").commands() end, desc = "Commands" },
        { "<leader>me", false },
        { "<leader>mh", false },
        { "<leader>mc", function() require("metals").compile_cascade() end, desc = "Compile Cascade" },
        { "<leader>mw", function() require("metals").hover_worksheet() end, desc = "Worksheet" },
        { "<leader>ml", function() require("metals").toggle_logs() end, desc = "Logs" },
        { "<leader>md", function() require("metals").run_doctor() end, desc = "Run Doctor" },
        { "<leader>mi", function() require("metals").import_build() end, desc = "Import Build" },
        { "<leader>mC", function() require("metals").compile_clean() end, desc = "Compile Clean" },
        { "<leader>mR", function() require("metals").reset_workspace() end, desc = "Reset Workspace" },
        { "<leader>mt", function() require("metals.tvp").toggle_tree_view() end, desc = "Toggle Tree View Panel" },
        { "<leader>mr", function() require("metals.tvp").reveal_in_tree() end, desc = "Reveal In Tree View Panel" },
      })

      return U.extend_tbl(opts, {
        servers = {
          metals = {
            keys = keys,
          },
        },
        setup = {
          metals = function()
            return true
          end,
        },
      })
    end,
  },
}
