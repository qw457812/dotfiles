return {
  {
    "echasnovski/mini.align",
    vscode = true,
    opts = {
      mappings = {
        start = "", -- disabled since text-case.nvim uses `ga`
        start_with_preview = "gA",
      },
    },
    keys = {
      -- { "ga", mode = { "n", "v" }, desc = "Align" },
      { "gA", mode = { "n", "v" }, desc = "Align with Preview" },
    },
  },

  {
    "echasnovski/mini.trailspace",
    event = { "BufReadPost", "BufNewFile" },
    opts = function()
      -- vim.api.nvim_create_autocmd("FileType", {
      --   pattern = { "dashboard" },
      --   callback = function(event)
      --     if package.loaded["mini.trailspace"] then
      --       vim.b[event.buf].minitrailspace_disable = true
      --       vim.api.nvim_buf_call(event.buf, require("mini.trailspace").unhighlight)
      --     end
      --   end,
      -- })
    end,
  },
}
