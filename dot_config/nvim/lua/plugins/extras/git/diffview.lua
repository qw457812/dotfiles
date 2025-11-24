return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<CR>", desc = "Diff View" },
      -- { "<leader>gD", "<cmd>DiffviewFileHistory<CR>", desc = "Diff Repo (Diff View)" },
      { "<leader>gF", "<cmd>DiffviewFileHistory %<CR>", desc = "File History (Diff View)" },
    },
    ---@param opts DiffviewConfig
    opts = function(_, opts)
      local actions = require("diffview.actions")

      LazyVim.extend(opts, "keymaps.view", {
        { "n", "q", actions.close, { desc = "Close" } },
      })
      LazyVim.extend(opts, "keymaps.file_panel", {
        { "n", "q", actions.close, { desc = "Close" } },
        {
          "n",
          "<Esc>",
          function()
            if not U.keymap.clear_ui_esc() then
              actions.close()
              vim.cmd("wincmd =")
            end
          end,
          desc = "Clear UI or Close",
        },
        {
          "n",
          "l",
          function()
            actions.select_entry()
            if vim.g.user_is_termux then
              actions.close()
              vim.cmd("wincmd =")
            end
          end,
          { desc = "Open" },
        },
      })
      LazyVim.extend(opts, "keymaps.file_history_panel", {
        { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close" } },
      })

      return U.extend_tbl(opts, {
        enhanced_diff_hl = true,
        view = {
          default = {
            -- FIXME: dropbar
            winbar_info = true,
          },
          merge_tool = {
            layout = "diff3_mixed",
          },
          file_history = {
            winbar_info = true,
          },
        },
        hooks = {
          view_opened = function(view)
            vim.t[view.tabpage].user_diffview = true
            if view.class:name() == "DiffView" then
              actions.toggle_files() -- Close DiffView:FilePanel initially
            end
          end,
        },
      })
    end,
    specs = {
      {
        "NeogitOrg/neogit",
        optional = true,
        opts = { integrations = { diffview = true } },
      },
    },
  },
}
