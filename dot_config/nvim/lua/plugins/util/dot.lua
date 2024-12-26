return {
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "karabiner.edn",
        callback = function(event)
          vim.b[event.buf].autoformat = false
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      vim.treesitter.language.register("vim", "vifm")
    end,
  },
}
