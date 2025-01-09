local csv_ft = { "csv", "tsv" }

return {
  {
    "hat0uma/csvview.nvim",
    ft = csv_ft,
    keys = {
      { "<leader>uc", "<cmd>CsvViewToggle<cr>", desc = "Csv View", ft = csv_ft },
    },
    opts = {
      -- view = { display_mode = "border" },
    },
    config = function(_, opts)
      require("csvview").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("csvview_auto_enable", { clear = true }),
        pattern = csv_ft,
        callback = function(event)
          local csvview = require("csvview")
          if not csvview.is_enabled(event.buf) then
            csvview.enable(event.buf)
          end
        end,
      })
    end,
  },
}
