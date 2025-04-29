return {
  {
    "harrisoncramer/gitlab.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "sindrets/diffview.nvim",
    },
    cond = vim.env.GITLAB_TOKEN ~= nil and vim.env.GITLAB_URL ~= nil,
    build = function()
      require("gitlab.server").build(true)
    end,
    -- stylua: ignore
    keys = {
      { "<leader>gaA", function() require("gitlab").approve() end, desc = "Approve MR" },
      { "<leader>gac", function() require("gitlab").choose_merge_request() end, desc = "Choose MR for review" },
      { "<leader>gaC", function() require("gitlab").create_mr() end, desc = "Create MR" },
      { "<leader>gad", function() require("gitlab").toggle_discussions() end, desc = "Toggle MR discussions" },
      { "<leader>gaD", function() require("gitlab").toggle_draft_mode() end, desc = "Toggle MR comment draft mode" },
      { "<leader>gaM", function() require("gitlab").merge() end, desc = "Merge MR" },
      { "<leader>gan", function() require("gitlab").create_note() end, desc = "Create MR note" },
      { "<leader>gao", function() require("gitlab").open_in_browser() end, desc = "Open MR in browser" },
      { "<leader>gap", function() require("gitlab").pipeline() end, desc = "Show MR pipeline status" },
      { "<leader>gaP", function() require("gitlab").publish_all_drafts() end, desc = "Publish all MR comment drafts" },
      { "<leader>gaR", function() require("gitlab").revoke() end, desc = "Revoke approval" },
      { "<leader>gas", function() require("gitlab").summary() end, desc = "Show MR summary" },
      { "<leader>gaS", function() require("gitlab").review() end, desc = "Start review" },
      { "<leader>gay", function() require("gitlab").copy_mr_url() end, desc = "Copy MR url" },
      { "<leader>gaaa", function() require("gitlab").add_assignee() end, desc = "Add MR assignee" },
      { "<leader>gaad", function() require("gitlab").delete_assignee() end, desc = "Delete MR assignee" },
      { "<leader>gala", function() require("gitlab").add_label() end, desc = "Add MR label" },
      { "<leader>gald", function() require("gitlab").delete_label() end, desc = "Delete MR label" },
      { "<leader>gara", function() require("gitlab").add_reviewer() end, desc = "Add MR reviewer" },
      { "<leader>gard", function() require("gitlab").delete_reviewer() end, desc = "Delete MR reviewer" },
    },
    opts = {
      keymaps = {
        global = {
          disable_all = true,
        },
      },
    },
    specs = {
      {
        "folke/which-key.nvim",
        opts = {
          spec = {
            { "<Leader>ga", group = "gitlab", icon = { icon = " ", color = "orange" } },
            { "<Leader>gaa", group = "assignee" },
            { "<Leader>gal", group = "label" },
            { "<Leader>gar", group = "reviewer" },
          },
        },
      },
    },
  },
}
