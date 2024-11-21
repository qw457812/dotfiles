if not LazyVim.has_extra("lang.markdown") then
  return {}
end

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      win_options = {
        -- toggling this plugin should also toggle conceallevel
        conceallevel = { default = 0 },
      },
      -- code = {
      --   disable_background = vim.g.user_transparent_background,
      -- },
    },
  },

  {
    "gaoDean/autolist.nvim",
    ft = "markdown",
    -- stylua: ignore
    keys = {
      { "<tab>",   "<cmd>AutolistTab<cr>",                ft = "markdown", mode = "i" },
      { "<s-tab>", "<cmd>AutolistShiftTab<cr>",           ft = "markdown", mode = "i" },
      { "<CR>",    "<CR><cmd>AutolistNewBullet<cr>",      ft = "markdown", mode = "i" },
      { "o",       "o<cmd>AutolistNewBullet<cr>",         ft = "markdown" },
      { "O",       "O<cmd>AutolistNewBulletBefore<cr>",   ft = "markdown" },
      { "<CR>",    "<cmd>AutolistToggleCheckbox<cr><CR>", ft = "markdown" },
      { "<M-r>",   "<cmd>AutolistRecalculate<cr>",        ft = "markdown" },
      { ">>",      ">><cmd>AutolistRecalculate<cr>",      ft = "markdown" },
      { "<<",      "<<<cmd>AutolistRecalculate<cr>",      ft = "markdown" },
      { "dd",      "dd<cmd>AutolistRecalculate<cr>",      ft = "markdown" },
      { "d",       "d<cmd>AutolistRecalculate<cr>",       ft = "markdown", mode = "v" },
    },
    opts = {},
    config = function(_, opts)
      require("autolist").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(event)
          -- cycle list types with dot-repeat
          vim.keymap.set(
            "n",
            "].",
            require("autolist").cycle_next_dr,
            { expr = true, buffer = event.buf, desc = "Next List Type" }
          )
          vim.keymap.set(
            "n",
            "[.",
            require("autolist").cycle_prev_dr,
            { expr = true, buffer = event.buf, desc = "Prev List Type" }
          )
        end,
      })
    end,
  },
}
