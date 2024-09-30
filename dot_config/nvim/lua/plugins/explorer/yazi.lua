return {
  -- https://github.com/sxyazi/dotfiles/blob/18ce3eda7792df659cb248d9636b8d7802844831/nvim/lua/plugins/ui.lua#L646
  {
    "mikavilpas/yazi.nvim",
    keys = {
      { "<leader><cr>", "<cmd>Yazi<cr>", desc = "Yazi (Buffer Dir)" },
    },
    opts = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(event)
          local buf = event.buf
          if vim.bo[buf].filetype == "yazi" then
            -- esc_esc = false
            vim.keymap.set("t", "<esc>", "<esc>", { buffer = buf, nowait = true })
            -- ctrl_hjkl = false
            vim.keymap.set("t", "<c-h>", "<c-h>", { buffer = buf, nowait = true })
            vim.keymap.set("t", "<c-j>", "<c-j>", { buffer = buf, nowait = true })
            vim.keymap.set("t", "<c-k>", "<c-k>", { buffer = buf, nowait = true })
            vim.keymap.set("t", "<c-l>", "<c-l>", { buffer = buf, nowait = true })
          end
        end,
      })

      return {
        open_for_directories = vim.g.user_default_explorer == "yazi.nvim",
      }
    end,
  },
}
