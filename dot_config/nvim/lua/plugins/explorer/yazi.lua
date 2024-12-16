return {
  -- https://github.com/sxyazi/dotfiles/blob/18ce3eda7792df659cb248d9636b8d7802844831/nvim/lua/plugins/ui.lua#L646
  -- https://github.com/mikavilpas/dotfiles/blob/main/.config/nvim/lua/plugins/my-file-manager.lua
  {
    "mikavilpas/yazi.nvim",
    keys = {
      { "<leader><cr>", "<cmd>Yazi<cr>", desc = "Yazi (Buffer Dir)" },
    },
    init = function(plugin)
      local opts = LazyVim.opts("yazi.nvim")
      if opts.open_for_directories then
        U.explorer.load_on_directory(plugin.name)
      end
    end,
    opts = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*yazi*",
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

          -- after closing `show_help` by <bs>, yazi goes to normal mode
          vim.api.nvim_create_autocmd("BufEnter", {
            buffer = buf,
            callback = function()
              vim.cmd.startinsert()
            end,
          })
        end,
      })

      -- -- already done, see: https://github.com/mikavilpas/yazi.nvim/blob/d09f94e79fc0a28f7242ff94af17ca96d8a41878/lua/yazi/event_handling/yazi_event_handling.lua#L76
      -- vim.api.nvim_create_autocmd("User", {
      --   pattern = "YaziRenamedOrMoved",
      --   ---@module 'yazi'
      --   ---@param event {data: YaziNeovimEvent.YaziRenamedOrMovedData}
      --   callback = function(event)
      --     for from, to in pairs(event.data.changes) do
      --       Snacks.rename.on_rename_file(from, to)
      --     end
      --   end,
      -- })

      ---@type YaziConfig
      return {
        open_for_directories = vim.g.user_hijack_netrw == "yazi.nvim",
        open_multiple_tabs = true,
        keymaps = {
          show_help = "~", -- `~` for yazi.nvim and `g?` for yazi
        },
        integrations = LazyVim.pick.picker.name == "fzf" and {
          grep_in_directory = "fzf-lua",
          grep_in_selected_files = "fzf-lua",
        } or nil,
        future_features = {
          ya_emit_reveal = true,
          ya_emit_open = true,
        },
      }
    end,
  },
}
