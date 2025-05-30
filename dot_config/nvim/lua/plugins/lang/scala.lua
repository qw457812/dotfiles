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
        { "<leader>co", function() require("metals").organize_imports() end, desc = "Organize Imports (Metals)" },
        { "<leader>im", function() require("metals").info() end, desc = "Metals" },
        { "<leader>m", "", desc = "+metals" },
        -- NOTE: need to run `:MetalsUpdate` to update (re-install) to the latest stable version or `opts.servers.metals.settings.serverVersion` of metals (~/.cache/nvim/nvim-metals/metals)
        { "<leader>mu", "<cmd>MetalsUpdate<cr>", desc = "Update Metals" },
        { "<leader>me", false },
        { "<leader>mc", function() require("metals").compile_cascade() end, desc = "Compile Cascade" },
        { "<leader>mh", function() require("metals").hover_worksheet() end, desc = "Hover Worksheet" },
        { "<leader>ml", function() require("metals").toggle_logs() end, desc = "Logs" },
        { "<leader>md", function() require("metals").run_doctor() end, desc = "Run Doctor" },
        { "<leader>mi", function() require("metals").import_build() end, desc = "Import Build" },
        { "<leader>mC", function() require("metals").compile_clean() end, desc = "Compile Clean" },
        { "<leader>mR", function() require("metals").reset_workspace() end, desc = "Reset Workspace" },
      })
    end,
  },
}
