return {
  -- alternative: https://github.com/TungstnBallon/conflict.nvim
  {
    "akinsho/git-conflict.nvim",
    event = { "LazyFile", "VeryLazy" },
    lazy = vim.fn.argc(-1) == 0, -- load git-conflict early when opening a file from the cmdline
    cmd = {
      "GitConflictChooseOurs",
      "GitConflictChooseTheirs",
      "GitConflictChooseBoth",
      "GitConflictChooseNone",
      "GitConflictNextConflict",
      "GitConflictPrevConflict",
      "GitConflictListQf",
      "GitConflictRefresh",
    },
    opts = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "GitConflictDetected",
        callback = function()
          local conflict_count = require("git-conflict").conflict_count()
          LazyVim.warn(
            ("`%d` conflicts detected in `%s`"):format(
              conflict_count,
              U.path.relative_to_root(vim.api.nvim_buf_get_name(0))
            ),
            { title = "Git Conflict" }
          )
        end,
      })
    end,
    specs = {
      {
        "nvim-lualine/lualine.nvim",
        optional = true,
        opts = function(_, opts)
          table.insert(opts.sections.lualine_x, 4, {
            function()
              local conflict = ""
              if package.loaded["git-conflict"] then
                local conflict_count = require("git-conflict").conflict_count()
                conflict = conflict_count > 0 and " " .. conflict_count or conflict -- 
              end
              return conflict
            end,
            color = function()
              return { fg = Snacks.util.color("GitConflictAncestorLabel", "bg") }
            end,
          })
        end,
      },
    },
  },
}
