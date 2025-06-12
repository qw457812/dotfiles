if not LazyVim.has_extra("lang.scala") then
  return {}
end

return {
  { "scalameta/nvim-metals", optional = true, ft = "java" },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      if not LazyVim.has("nvim-metals") then
        return
      end

      -- HACK: add java to filetypes in favor of `gr` (lsp references) in java files
      -- see: https://github.com/LazyVim/LazyVim/blob/859646f628ff0d99e6afe835ba0a48faed2972af/lua/lazyvim/plugins/extras/lang/scala.lua#L55-L69
      local setup_metals_orig = opts.setup.metals
      opts.setup.metals = function(...)
        local ret = setup_metals_orig(...)

        local autocmds = vim.api.nvim_get_autocmds({
          event = "FileType",
          group = vim.api.nvim_create_augroup("nvim-metals", { clear = false }),
        })
        if #autocmds > 0 then
          local metals_did_attach = false
          LazyVim.lsp.on_attach(function()
            metals_did_attach = true
            ---@diagnostic disable-next-line: redundant-return-value
            return true
          end, "metals")
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "java",
            callback = function()
              if metals_did_attach then
                autocmds[1].callback()
              end
            end,
            group = vim.api.nvim_create_augroup("nvim-metals-java", { clear = true }),
          })
        end

        return ret
      end

      -- stylua: ignore
      vim.list_extend(opts.servers.metals.keys, {
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

      -- https://github.com/ckipp01/dots/blob/c9e829c15a64ca1febe4ebc7544997974e0e5952/nvim/.config/nvim/lua/mesopotamia/lsp.lua#L42
      opts.servers.metals = U.extend_tbl(opts.servers.metals, {
        tvp = {
          icons = {
            enabled = true,
          },
        },
        settings = {
          -- serverVersion = "latest.snapshot", -- run `:MetalsUpdate` after changing this
          autoImportBuild = "all", -- initial
          defaultBspToBuildTool = true, -- see also: https://github.com/scalameta/metals/discussions/4505
          showInferredType = true,
          showImplicitConversionsAndClasses = true,
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
      })
    end,
  },
}
