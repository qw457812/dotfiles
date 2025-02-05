return {
  {
    "echasnovski/mini.align",
    vscode = true,
    keys = {
      -- { "ga", mode = { "n", "x" }, desc = "Align" },
      {
        "gA",
        mode = {
          -- "n",
          "x",
        },
        desc = "Align with Preview",
      },
    },
    opts = {
      mappings = {
        start = "", -- disabled since text-case.nvim or coerce.nvim uses `ga`
        start_with_preview = "gA",
      },
    },
    config = function(_, opts)
      local orig_gA_keymap = vim.fn.maparg("gA", "n", false, true) --[[@as table<string,any>]]
      require("mini.align").setup(opts)
      if not vim.tbl_isempty(orig_gA_keymap) then
        vim.fn.mapset(orig_gA_keymap) -- orgmode uses `gA`
      end
    end,
  },

  {
    "echasnovski/mini.trailspace",
    event = { "BufReadPost", "BufNewFile" },
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "gitcommit", -- git commit --verbose
        },
        callback = function(event)
          vim.b[event.buf].minitrailspace_disable = true
          -- if package.loaded["mini.trailspace"] then
          --   vim.api.nvim_buf_call(event.buf, require("mini.trailspace").unhighlight)
          -- end
        end,
      })
    end,
  },
}
