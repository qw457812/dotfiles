if not LazyVim.has_extra("lang.sql") then
  return {}
end

local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "kristijanhusak/vim-dadbod-ui",
    optional = true,
    keys = function(_, keys)
      vim.g.db_ui_disable_info_notifications = 1
      vim.g.db_ui_disable_mappings_sql = 1

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dbui",
        callback = function(event)
          vim.keymap.del("n", "H", { buffer = event.buf }) -- original <Plug>(DBUI_ToggleDetails)
        end,
      })

      return vim.list_extend(keys, {
        { "<cr>", mode = { "n", "v" }, "<Plug>(DBUI_ExecuteQuery)", desc = "Execute Query (dadbod)", ft = sql_ft },
        { "<leader>fs", "<Plug>(DBUI_SaveQuery)", desc = "Save Query (dadbod)", ft = sql_ft },
        { "<localleader>e", "<Plug>(DBUI_EditBindParameters)", desc = "Edit Bind Parameters (dadbod)", ft = sql_ft },
        { "a", "<Plug>(DBUI_AddConnection)", desc = "Add Connection (dadbod)", ft = "dbui" },
        { "gd", "<Plug>(DBUI_ToggleDetails)", desc = "Toggle Details (dadbod)", ft = "dbui" },
        { "<localleader>f", "<Plug>(DBUI_JumpToForeignKey)", desc = "Jump To Foreign Key (dadbod)", ft = "dbout" },
        { "<localleader>r", "<Plug>(DBUI_ToggleResultLayout)", desc = "Toggle Result Layout (dadbod)", ft = "dbout" },
        {
          "<esc>",
          function()
            if not U.keymap.clear_ui_esc() then
              vim.cmd("wincmd p")
            end
          end,
          desc = "Clear UI or Unfocus (dadbod)",
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
        -- -- vim-dadbod-ui
        -- {
        --   filter = {
        --     event = "notify",
        --     any = {
        --       { find = "^Connecting to db .+%.%.%.$" },
        --       { find = "^Connected to db .+ after .+ sec%.$" },
        --       { find = "^Executing query%.%.%.$" },
        --       { find = "^Done after .+ sec%.$" },
        --     },
        --   },
        --   view = "mini",
        -- },
        -- vim-dadbod
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "^DB: Query .+ finished in .+s$" },
              { find = "^DB: Running query%.%.%.$" },
            },
          },
          view = "mini",
        },
      })
      return opts
    end,
  },

  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      for _, view in ipairs(opts.right or {}) do
        if view.ft == "dbui" and view.pinned then
          view.pinned = false
          break
        end
      end
    end,
  },

  { "jsborjesson/vim-uppercase-sql", ft = "sql" },
}
