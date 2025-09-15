if not LazyVim.has_extra("lang.sql") then
  return {}
end

local sql_ft = { "sql", "mysql", "plsql" }

---@type LazySpec
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
          for _, key in ipairs({ "H", "<c-j>", "<c-k>" }) do
            pcall(vim.keymap.del, "n", key, { buffer = event.buf })
          end
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
        { "<esc>", U.keymap.clear_ui_or_unfocus_esc, desc = "Clear UI or Unfocus (dadbod)", ft = { "dbui", "dbout" } },
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

  -- -- sqlfluff -> sqruff
  -- {
  --   "mason-org/mason.nvim",
  --   opts = function(_, opts)
  --     for i, pkg in ipairs(opts.ensure_installed) do
  --       if pkg == "sqlfluff" then
  --         table.remove(opts.ensure_installed, i)
  --         break
  --       end
  --     end
  --     table.insert(opts.ensure_installed, "sqruff")
  --   end,
  -- },
  -- {
  --   "mfussenegger/nvim-lint",
  --   optional = true,
  --   opts = function(_, opts)
  --     for _, ft in ipairs(sql_ft) do
  --       opts.linters_by_ft[ft] = opts.linters_by_ft[ft] or {}
  --       for i, linter in ipairs(opts.linters_by_ft[ft]) do
  --         if linter == "sqlfluff" then
  --           table.remove(opts.linters_by_ft[ft], i)
  --           break
  --         end
  --       end
  --       table.insert(opts.linters_by_ft[ft], "sqruff")
  --     end
  --   end,
  -- },
  -- {
  --   "stevearc/conform.nvim",
  --   optional = true,
  --   opts = function(_, opts)
  --     opts.formatters.sqlfluff = nil
  --     for _, ft in ipairs(sql_ft) do
  --       opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
  --       for i, formatter in ipairs(opts.formatters_by_ft[ft]) do
  --         if formatter == "sqlfluff" then
  --           table.remove(opts.formatters_by_ft[ft], i)
  --           break
  --         end
  --       end
  --       table.insert(opts.formatters_by_ft[ft], "sqruff")
  --     end
  --   end,
  -- },
}
