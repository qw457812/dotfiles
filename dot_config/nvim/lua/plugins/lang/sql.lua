if not LazyVim.has_extra("lang.sql") then
  return {}
end

local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "kristijanhusak/vim-dadbod-ui",
    optional = true,
    keys = function(_, keys)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dbui",
        callback = function(event)
          vim.keymap.del("n", "H", { buffer = event.buf }) -- original <Plug>(DBUI_ToggleDetails)
        end,
      })

      return vim.list_extend(keys, {
        { "<cr>", mode = { "n", "v" }, "<Plug>(DBUI_ExecuteQuery)", desc = "Execute Query (dadbod)", ft = sql_ft },
        { "<leader>fs", "<Plug>(DBUI_SaveQuery)", desc = "Save Query (dadbod)", ft = sql_ft },
        { "gd", "<Plug>(DBUI_ToggleDetails)", desc = "Toggle Details (dadbod)", ft = "dbui" },
        {
          "<esc>",
          function()
            vim.cmd(vim.v.hlsearch == 1 and "nohlsearch" or "wincmd p")
          end,
          desc = "Clear hlsearch or Unfocus (dadbod)",
          ft = { "dbui", "dbout" },
        },
      })
    end,
  },
  {
    "folke/noice.nvim",
    optional = true,
    opts = function(_, opts)
      opts.routes = vim.list_extend(opts.routes or {}, {
        -- vim-dadbod-ui
        {
          filter = {
            event = "notify",
            any = {
              { find = "^Connecting to db .+%.%.%.$" },
              { find = "^Connected to db .+ after .+ sec%.$" },
              { find = "^Executing query%.%.%.$" },
              { find = "^Done after .+ sec%.$" },
            },
          },
          view = "mini",
        },
        -- vim-dadbod
        {
          filter = {
            event = "msg_show",
            find = "^DB: Query .+ finished in .+s$",
          },
          view = "mini",
        },
      })
      return opts
    end,
  },

  { "jsborjesson/vim-uppercase-sql", ft = "sql" },
}
